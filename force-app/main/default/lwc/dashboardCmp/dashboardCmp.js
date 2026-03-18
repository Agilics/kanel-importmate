import { LightningElement, track, wire,api } from 'lwc';
import getDashboardData from '@salesforce/apex/DashboardController.getDashboardData';
import deleteProject from '@salesforce/apex/DashboardController.deleteProject';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { navigateToPage } from 'c/utility'
import LightningConfirm from "lightning/confirm";
// import labels for tab filters
import Dashboard_Filter_All_Project from '@salesforce/label/c.Dashboard_FilterTab_All_Projects';
import Dashboard_Filter_Active from '@salesforce/label/c.Dashboard_FilterTab_Active';
import Dashboard_Filter_Completed from '@salesforce/label/c.Dashboard_FilterTab_Completed'; 
import Dashboard_Filter_Scheduled from '@salesforce/label/c.Dashboard_FilterTab_Scheduled';

import Dashboard_Input_Search_Placeholder from '@salesforce/label/c.Dashboard_Input_Search_Projects_Placeholder';
import Dashboard_FilterTab_Title from '@salesforce/label/c.Dashboard_FilterTab_Title';
import Dashboard_Project_Details_Title from '@salesforce/label/c.Dashboard_FilterTab_Subtitle';

import Dashboard_Delete_Confirm_Header from '@salesforce/label/c.Dashboard_Delete_Confirm_Header'; 

//import labels for toast messages & dialog confirmation
import Dashboard_Delete_Confirm from '@salesforce/label/c.Dashboard_Confirm_Delete_Message';
import Dashboard_Delete_Success from '@salesforce/label/c.Dashboard_Delete_Success_Message';
 
// Label for no projects message
import Dashboard_No_Projects from '@salesforce/label/c.Dashboard_No_Project_Message';
import Dashboard_No_Project_Error_Message from '@salesforce/label/c.Dashboard_No_Project_Error_Message';

// Card Key Metrics labels
import Dashboard_Stat_Total_Projects from '@salesforce/label/c.Dashboard_Stat_TotalProjects';
import Dashboard_Stat_Records_Imported from '@salesforce/label/c.Dashboard_Stat_RecordImported';
import Dashboard_Stat_Success_Rate from '@salesforce/label/c.Dashboard_Stat_SuccessRate';
import Dashboard_Stat_Active_Projects from '@salesforce/label/c.Dashboard_Stat_ActiveProject';

// label for buttons

import Dashboard_Button_New_Project from '@salesforce/label/c.Dashboard_Button_New_Project';
import Dashboard_Button_Create_First_Project from '@salesforce/label/c.Dashboard_Button_Create_First_Project';

export default class DashboardCmp extends LightningElement {
    @track stats = [];

    @track filterTabs = [
        { label: Dashboard_Filter_All_Project, value: 'all', active: true },
        { label: Dashboard_Filter_Active, value: 'active', active: false },
        { label: Dashboard_Filter_Completed, value: 'completed', active: false },
        { label: Dashboard_Filter_Scheduled, value: 'scheduled', active: false }
    ];

    @track projects = [];
    @track allProjects = [];
    @track isLoading = false;
    @track error;
    searchTerm = '';
    wiredDashboardResult;

    buttonLabel = {
        newProject: Dashboard_Button_New_Project,
        createFirstProject: Dashboard_Button_Create_First_Project
    };

    sections ={
        title: Dashboard_FilterTab_Title,
        detailsTitle: Dashboard_Project_Details_Title
    }

    placeholder = Dashboard_Input_Search_Placeholder;

    @wire(getDashboardData, { limitor: 50 })
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        if (result.data) {
            this.allProjects = (result.data.projects || []).map((project) => this.normalizeProject(project));
            this.projects = [...this.allProjects];
            this.stats = this.buildStats(result.data.stats, this.allProjects);

            this.isLoading = false;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.projects = [];
            this.allProjects = [];
            this.stats = [];
            this.isLoading = false;
            console.error('Error loading dashboard data:', result.error);
        }
    }

    get hasProjects() {
        return this.projects && this.projects.length > 0;
    }

    get noProjectsMessage() {
        if (this.isLoading) {
            return Dashboard_Loading_Message;
        }
        if (this.error) {
            return Dashboard_No_Project_Error_Message;
        }
        return  Dashboard_No_Projects;
    }

    handleSearch(event) {
        this.searchTerm = (event.target.value || '').toLowerCase();
        this.filterProjects();
    }

    handleNewProject() {
        this.dispatchEvent(new CustomEvent('newproject'));
    }

    handleFilterChange(event) {
        const selectedValue = event.currentTarget.dataset.value;
        this.filterTabs = this.filterTabs.map((tab) => {
            const active = tab.value === selectedValue;
            return {
                ...tab,
                active,
                className: active ? 'filter-tab active' : 'filter-tab'
            };
        });
        this.filterProjects();
    }

    filterProjects() {
        const activeFilter = this.filterTabs.find((tab) => tab.active)?.value || 'all';
        let filtered = [...this.allProjects];

        if (activeFilter !== 'all') {
            filtered = filtered.filter((project) => {
                const status = project._normalizedStatus;

                if (activeFilter === 'active') {
                    return status === 'inprogress';
                }
                if (activeFilter === 'completed') {
                    return status === 'completed';
                }
                if (activeFilter === 'scheduled') {
                    return status === 'pending';
                }
                return false;
            });
        }

        if (this.searchTerm) {
            filtered = filtered.filter((project) => {
                const name = (project.Name || '').toLowerCase();
                const target = (project.TargetObject__c || '').toLowerCase();
                const description = (project.Description__c || '').toLowerCase();
                return (
                    name.includes(this.searchTerm) ||
                    target.includes(this.searchTerm) ||
                    description.includes(this.searchTerm)
                );
            });
        }

        this.projects = filtered;
    }

    normalizeProject(project) {
        const normalized = { ...project };
        const lastExecution = project?.ImportExecutions__r?.length ? project.ImportExecutions__r[0] : null;

        const total = Number(lastExecution?.TotalRecords__c || 0);
        const processed = Number(lastExecution?.ProcessedRecords__c || 0);
        const failed = Number(lastExecution?.FailedRecords__c || 0);
        const statusRaw = (lastExecution?.Status__c || '').toLowerCase();

        normalized._lastExecution = lastExecution;
        normalized._totalRecords = Math.max(0, total);
        normalized._processedRecords = Math.max(0, processed);
        normalized._failedRecords = Math.max(0, failed);
        normalized._successRecords = Math.max(0, normalized._processedRecords - normalized._failedRecords);
        normalized._normalizedStatus = this.normalizeStatus(statusRaw);

        return normalized;
    }

    normalizeStatus(status) {
        if (status === 'inprogress' || status === 'in progress') return 'inprogress';
        if (status === 'pending') return 'pending';
        if (status === 'completed') return 'completed';
        if (status === 'failed') return 'failed';
        if (status === 'cancelled') return 'cancelled';
        return 'draft';
    }

    buildStats(serverStats, projects) {
        const totalProjects = Number(serverStats?.totalProjects ?? (projects || []).length);
        const recordsImported = serverStats?.recordsImportedFormatted || this.formatNumber(serverStats?.totalRecordsImported);
        const successRate = serverStats?.successRateFormatted || '0%';
        let activeProjects = 0;

        (projects || []).forEach((project) => {
            if (project._normalizedStatus === 'inprogress' || project._normalizedStatus === 'pending') {
                activeProjects += 1;
            }
        });

        return [
              {
                id: 1,
                label: Dashboard_Stat_Total_Projects,
                value: String(totalProjects || 0),
                change: '',
                changeLabel: '',
                icon: 'standard:folder',
                iconColor: 'blue'
            }, {
                id: 2,
                label: Dashboard_Stat_Records_Imported,
                value: recordsImported  || '0',
                change: '',
                changeLabel: '',
                icon: 'standard:data_integration_hub',
                iconColor: 'green'
            }, {
                id: 3,
                label: Dashboard_Stat_Success_Rate,
                value: successRate ,
                change: '',
                changeLabel: '',
                icon: 'standard:approval',
                iconColor: 'green'
            }, {
                id: 4,
                label: Dashboard_Stat_Active_Projects,
                value: String(activeProjects),
                change: '',
                changeLabel: '',
                icon: 'standard:event',
                iconColor: 'purple'
            } 
        ];
    }

    formatNumber(value) {
        const num = Number(value || 0);
        if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`;
        if (num >= 1000) return `${(num / 1000).toFixed(1)}K`;
        return String(Math.round(num));
    }

    handleProjectSelect(event) {
        const projectId = event.detail;
        this.dispatchEvent(new CustomEvent('projectselect', {
            detail: projectId
        }));
    }

    handleProjectEdit(event) {
        const projectId = event.detail;
        this.dispatchEvent(new CustomEvent('projectedit', {
            detail: projectId
        }));
    }

     //suppression d'un projet avec confirmation
    async handleProjectDelete(event) {
        const projectId = event.detail;
        
        const confirm = await LightningConfirm.open({
            message: Dashboard_Delete_Confirm,
            variant: 'header',
            label: Dashboard_Delete_Confirm_Header,
            theme: 'alt-inverse'
        });
        // Confirm deletion
        if (!confirm) {
            return;
        }

        try {
            this.isLoading = true;
            await deleteProject({ projectId: projectId });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: Dashboard_Delete_Success,
                variant: 'success'
            }));

            await this.refreshDashboard();
        } catch (error) {
            console.error('Error deleting project:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Error deleting project',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    @api
    async refreshDashboard() {
        return refreshApex(this.wiredDashboardResult);
    }
}