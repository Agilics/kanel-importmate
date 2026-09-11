import { LightningElement, track, wire, api } from 'lwc';
import getDashboardData from '@salesforce/apex/DashboardController.getDashboardData';
import deleteProject    from '@salesforce/apex/DashboardController.deleteProject';
import { refreshApex }  from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { navigateToPage } from 'c/utility';
import LightningConfirm  from 'lightning/confirm';

// ─── Labels : filter tabs ─────────────────────────────────────────────────────
import Dashboard_Filter_All_Project from '@salesforce/label/c.Dashboard_FilterTab_All_Projects';
import Dashboard_Filter_Active      from '@salesforce/label/c.Dashboard_FilterTab_Active';
import Dashboard_Filter_Completed   from '@salesforce/label/c.Dashboard_FilterTab_Completed';
import Dashboard_Filter_Scheduled   from '@salesforce/label/c.Dashboard_FilterTab_Scheduled';

// ─── Labels : header / search ────────────────────────────────────────────────
import Dashboard_Input_Search_Placeholder from '@salesforce/label/c.Dashboard_Input_Search_Projects_Placeholder';
import Dashboard_FilterTab_Title          from '@salesforce/label/c.Dashboard_FilterTab_Title';
import Dashboard_Project_Details_Title    from '@salesforce/label/c.Dashboard_FilterTab_Subtitle';

// ─── Labels : delete dialog ───────────────────────────────────────────────────
import Dashboard_Delete_Confirm_Header from '@salesforce/label/c.Dashboard_Delete_Confirm_Header';
import Dashboard_Delete_Confirm        from '@salesforce/label/c.Dashboard_Confirm_Delete_Message';
import Dashboard_Delete_Success        from '@salesforce/label/c.Dashboard_Delete_Success_Message';

// ─── Labels : empty / error states ───────────────────────────────────────────
import Dashboard_No_Projects             from '@salesforce/label/c.Dashboard_No_Project_Message';
import Dashboard_No_Project_Error_Message from '@salesforce/label/c.Dashboard_No_Project_Error_Message';

// ─── Labels : KPI stat cards ─────────────────────────────────────────────────
import Dashboard_Stat_Total_Projects   from '@salesforce/label/c.Dashboard_Stat_TotalProjects';
import Dashboard_Stat_Records_Imported from '@salesforce/label/c.Dashboard_Stat_RecordImported';
import Dashboard_Stat_Success_Rate     from '@salesforce/label/c.Dashboard_Stat_SuccessRate';
import Dashboard_Stat_Active_Projects  from '@salesforce/label/c.Dashboard_Stat_ActiveProject';

// ─── Labels : buttons ────────────────────────────────────────────────────────
import Dashboard_Button_New_Project          from '@salesforce/label/c.Dashboard_Button_New_Project';
import Dashboard_Button_Create_First_Project from '@salesforce/label/c.Dashboard_Button_Create_First_Project';

export default class DashboardCmp extends LightningElement {

    @track stats       = [];
    @track projects    = [];
    @track allProjects = [];
    @track isLoading   = false;
    @track error;
    searchTerm         = '';
    wiredDashboardResult;

    // ── Filter tabs ───────────────────────────────────────────────────────────
    @track filterTabs = [
        { label: Dashboard_Filter_All_Project, value: 'all',       active: true,  className: 'filter-btn active' },
        { label: Dashboard_Filter_Active,      value: 'active',    active: false, className: 'filter-btn' },
        { label: Dashboard_Filter_Completed,   value: 'completed', active: false, className: 'filter-btn' },
        { label: Dashboard_Filter_Scheduled,   value: 'scheduled', active: false, className: 'filter-btn' }
    ];

    // ── Bound label objects ───────────────────────────────────────────────────
    buttonLabel = {
        newProject:          Dashboard_Button_New_Project,
        createFirstProject:  Dashboard_Button_Create_First_Project
    };

    sections = {
        title:        Dashboard_FilterTab_Title,
        detailsTitle: Dashboard_Project_Details_Title
    };

    placeholder = Dashboard_Input_Search_Placeholder;

    // ─────────────────────────────────────────────────────────────────────────
    // Wire
    // ─────────────────────────────────────────────────────────────────────────

    @wire(getDashboardData, { limitor: 50 })
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        if (result.data) {
            this.allProjects = (result.data.projects || []).map(p => this.normalizeProject(p));
            this.projects    = [...this.allProjects];
            this.stats       = this.buildStats(result.data.stats, this.allProjects);
            this.isLoading   = false;
            this.error       = undefined;
        } else if (result.error) {
            this.error       = result.error;
            this.projects    = [];
            this.allProjects = [];
            this.stats       = [];
            this.isLoading   = false;
            console.error('Error loading dashboard data:', result.error);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Getters
    // ─────────────────────────────────────────────────────────────────────────

    get hasProjects() {
        return this.projects && this.projects.length > 0;
    }

    // [FIX] Was returning hardcoded English strings — now uses imported labels
    get noProjectsMessage() {
        if (this.isLoading) return 'Loading projects...';
        if (this.error)     return Dashboard_No_Project_Error_Message;
        return Dashboard_No_Projects;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Event handlers
    // ─────────────────────────────────────────────────────────────────────────

    handleSearch(event) {
        this.searchTerm = (event.target.value || '').toLowerCase();
        this.filterProjects();
    }

    handleNewProject() {
        this.dispatchEvent(new CustomEvent('newproject'));
    }

    handleFilterChange(event) {
        const selectedValue = event.currentTarget.dataset.value;
        this.filterTabs = this.filterTabs.map(tab => ({
            ...tab,
            active:    tab.value === selectedValue,
            className: tab.value === selectedValue ? 'filter-btn active' : 'filter-btn'
        }));
        this.filterProjects();
    }

    handleProjectSelect(event) {
        this.dispatchEvent(new CustomEvent('projectselect', { detail: event.detail }));
    }

    handleProjectEdit(event) {
        this.dispatchEvent(new CustomEvent('projectedit', { detail: event.detail }));
    }

    // [FIX] Was using hardcoded strings in LightningConfirm + ShowToastEvent
    async handleProjectDelete(event) {
        const projectId = event.detail;

        const isConfirm = await LightningConfirm.open({
            message: Dashboard_Delete_Confirm,          // ← label (was hardcoded EN)
            variant: 'header',
            label:   Dashboard_Delete_Confirm_Header,   // ← label (was hardcoded EN)
            theme:   'alt-inverse'
        });

        if (!isConfirm) return;

        try {
            this.isLoading = true;
            await deleteProject({ projectId });

            this.dispatchEvent(new ShowToastEvent({
                title:   'Success',
                message: Dashboard_Delete_Success,       // ← label (was hardcoded EN)
                variant: 'success'
            }));

            await this.refreshDashboard();
        } catch (error) {
            console.error('Error deleting project:', error);
            this.dispatchEvent(new ShowToastEvent({
                title:   'Error',
                message: error.body?.message || 'Error deleting project',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Filtering / normalisation
    // ─────────────────────────────────────────────────────────────────────────

    filterProjects() {
        const activeFilter = this.filterTabs.find(t => t.active)?.value || 'all';
        let filtered = [...this.allProjects];

        if (activeFilter !== 'all') {
            filtered = filtered.filter(project => {
                const s = project._normalizedStatus;
                if (activeFilter === 'active')    return s === 'inprogress';
                if (activeFilter === 'completed') return s === 'completed';
                if (activeFilter === 'scheduled') return s === 'pending';
                return false;
            });
        }

        if (this.searchTerm) {
            filtered = filtered.filter(project =>
                (project.Name            || '').toLowerCase().includes(this.searchTerm) ||
                (project.TargetObject__c || '').toLowerCase().includes(this.searchTerm) ||
                (project.Description__c  || '').toLowerCase().includes(this.searchTerm)
            );
        }

        this.projects = filtered;
    }

    normalizeProject(project) {
        const normalized    = { ...project };
        const lastExecution = project?.ImportExecutions__r?.length ? project.ImportExecutions__r[0] : null;

        const total     = Number(lastExecution?.TotalRecords__c     || 0);
        const processed = Number(lastExecution?.ProcessedRecords__c || 0);
        const failed    = Number(lastExecution?.FailedRecords__c    || 0);
        const statusRaw = (lastExecution?.Status__c || '').toLowerCase();

        normalized._lastExecution    = lastExecution;
        normalized._totalRecords     = Math.max(0, total);
        normalized._processedRecords = Math.max(0, processed);
        normalized._failedRecords    = Math.max(0, failed);
        normalized._successRecords   = Math.max(0, processed - failed);
        normalized._normalizedStatus = this.normalizeStatus(statusRaw);

        return normalized;
    }

    normalizeStatus(status) {
        if (status === 'inprogress' || status === 'in progress') return 'inprogress';
        if (status === 'pending')   return 'pending';
        if (status === 'completed') return 'completed';
        if (status === 'failed')    return 'failed';
        if (status === 'cancelled') return 'cancelled';
        return 'draft';
    }

    // [FIX] Was using hardcoded English strings — now uses imported label variables
    buildStats(serverStats, projects) {
        const totalProjects   = Number(serverStats?.totalProjects ?? (projects || []).length);
        const recordsImported = serverStats?.recordsImportedFormatted || this.formatNumber(serverStats?.totalRecordsImported);
        const successRate     = serverStats?.successRateFormatted || '0%';
        let   activeProjects  = 0;

        (projects || []).forEach(p => {
            if (p._normalizedStatus === 'inprogress' || p._normalizedStatus === 'pending') {
                activeProjects += 1;
            }
        });

        return [
            {
                id:          1,
                label:       Dashboard_Stat_Total_Projects,   // ← label (was 'Total Projects')
                value:       String(totalProjects),
                change:      '',
                changeLabel: '',
                icon:        '📁',
                iconColor:   'blue'
            },
            {
                id:          2,
                label:       Dashboard_Stat_Records_Imported, // ← label (was 'Records Imported')
                value:       recordsImported,
                change:      '',
                changeLabel: '',
                icon:        '📊',
                iconColor:   'green'
            },
            {
                id:          3,
                label:       Dashboard_Stat_Success_Rate,
                value:       successRate,
                change:      '',
                changeLabel: '',
                icon:        '✓',
                iconColor:   'green'
            },
            {
                id:          4,
                label:       Dashboard_Stat_Active_Projects,
                value:       String(activeProjects),
                change:      '',
                changeLabel: '',
                icon:        '⚡',
                iconColor:   'purple'
            }
        ];
    }

    formatNumber(value) {
        const num = Number(value || 0);
        if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M`;
        if (num >= 1_000)     return `${(num / 1_000).toFixed(1)}K`;
        return String(Math.round(num));
    } 
    
    @api
    async refreshDashboard() {
        return refreshApex(this.wiredDashboardResult);
    }
}