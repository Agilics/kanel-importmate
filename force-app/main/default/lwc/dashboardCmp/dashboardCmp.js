import { LightningElement, track, wire } from 'lwc';
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

    // Wire to get dashboard data
    @wire(getDashboardData, { limitor: 50 })
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        if (result.data) {
            // Process projects
            this.allProjects = result.data.projects || [];
            this.projects = [...this.allProjects];
            
            // Process stats
            if (result.data.stats) {
                this.stats = [
                    {
                        id: 1,
                        label: Dashboard_Stat_Total_Projects,
                        value: String(result.data.stats.totalProjects || 0),
                        change: '',
                        changeLabel: '',
                        icon: 'standard:folder',
                        iconColor: 'blue'
                    },
                    {
                        id: 2,
                        label: Dashboard_Stat_Records_Imported,
                        value: result.data.stats.recordsImportedFormatted || '0',
                        change: '',
                        changeLabel: '',
                        icon: 'standard:data_integration_hub',
                        iconColor: 'green'
                    },
                    {
                        id: 3,
                        label: Dashboard_Stat_Success_Rate,
                        value: result.data.stats.successRateFormatted || '0%',
                        change: '',
                        changeLabel: '',
                        icon: 'standard:approval',
                        iconColor: 'green'
                    },
                    {
                        id: 4,
                        label: Dashboard_Stat_Active_Projects,
                        value: String(result.data.stats.activeSchedules || 0),
                        change: '',
                        changeLabel: '',
                        icon: 'standard:event',
                        iconColor: 'purple'
                    }
                ];
            }
            
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

    //vérification de la présence de projets pour afficher le message approprié
    get hasProjects() {
        return this.projects && this.projects.length > 0;
    }

    //vérification de l'état de chargement ou d'erreur pour afficher le message approprié
    get noProjectsMessage() {
        if (this.isLoading) {
            return 'Loading projects...';
        }
        if (this.error) {
            return Dashboard_No_Project_Error_Message;
        }
        return Dashboard_No_Projects;
    }

    //recherche de projets par nom, cible ou description
    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.filterProjects();
    }

    //création d'un nouveau projet
    handleNewProject() {
        this.dispatchEvent(new CustomEvent('newproject'));
    }

    // gestion du changement de filtre
    handleFilterChange(event) {
        const selectedValue = event.currentTarget.dataset.value;
        this.filterTabs = this.filterTabs.map(tab => ({
            ...tab,
            active: tab.value === selectedValue
        }));
        this.filterProjects();
    }

    // filtrage des projets en fonction du statut et de la recherche
    filterProjects() {
        const activeFilter = this.filterTabs.find(tab => tab.active)?.value || 'all';
        let filtered = [...this.allProjects];

        // Apply status filter
        if (activeFilter !== 'all') {
            filtered = filtered.filter(project => {
                // Récupérer le statut depuis la dernière exécution
                const lastExecution = project.ImportExecutions__r && project.ImportExecutions__r.length > 0 
                    ? project.ImportExecutions__r[0] 
                    : null;
                const status = (lastExecution?.Status__c || '').toLowerCase();
                
                // Mapper les statuts aux filtres
                if (activeFilter === 'active') {
                    return status === 'inprogress' || status === 'pending';
                } else if (activeFilter === 'completed') {
                    return status === 'completed';
                } else if (activeFilter === 'scheduled') {
                    return status === 'pending';
                }
                return false;
            });
        }

        // Apply search filter
        if (this.searchTerm) {
            filtered = filtered.filter(project => {
                const name = (project.Name || '').toLowerCase();
                const target = (project.TargetObject__c || '').toLowerCase();
                const description = (project.Description__c || '').toLowerCase();
                return name.includes(this.searchTerm) || 
                       target.includes(this.searchTerm) || 
                       description.includes(this.searchTerm);
            });
        }

        this.projects = filtered;
    }

    //sélection d'un projet
    handleProjectSelect(event) {
        const projectId = event.detail;
        this.dispatchEvent(new CustomEvent('projectselect', {
            detail: projectId
        }));
    }

    //modification d'un projet
    handleProjectEdit(event) {
        const projectId = event.detail;
        // Dispatch edit event to parent
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
            theme: 'warning'
        });
        // Confirm deletion
        if (!confirm) {
            return;
        }
        
        try {
            this.isLoading = true;
            await deleteProject({ projectId: projectId });
            
            // Show success toast
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: Dashboard_Delete_Success,
                variant: 'success'
            }));
            
            // Refresh dashboard data
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

    async refreshDashboard() {
        return refreshApex(this.wiredDashboardResult);
    }
}