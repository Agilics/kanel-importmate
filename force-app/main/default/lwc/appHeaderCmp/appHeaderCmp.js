import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import imLogo from '@salesforce/resourceUrl/im_logo';

export default class AppHeaderCmp extends LightningElement {
    @api currentPage = 'dashboard'; // Page actuelle

    // Logo static resource
    logoUrl = null;

    // Propriétés pour classes actives
    @track dashboardClass = '';
    @track projectsClass = '';
    @track logsClass = '';
    @track settingsClass = '';

    connectedCallback() {
        this.updateClasses();
    }

    // Mise à jour des classes basées sur currentPage
    updateClasses() {
        this.dashboardClass = this.currentPage === 'dashboard' ? 'active' : '';
        this.projectsClass = this.currentPage === 'projects' ? 'active' : '';
        this.logsClass = this.currentPage === 'logs' ? 'active' : '';
        this.settingsClass = this.currentPage === 'settings' ? 'active' : '';
    }

    handleNavigation(event) {
        const page = event.currentTarget.dataset.page;
        if (page) {
            this.currentPage = page;
            this.updateClasses();
            // Émettre un event pour changer le main content
            this.dispatchEvent(new CustomEvent('navigate', { 
                detail: { page: this.currentPage }, 
                bubbles: true, 
                composed: true 
            }));
        }
    }

    handleNotifications() {
        this.showToast('Notifications', 'Coming soon', 'info');
    }

    handleUserMenu() {
        console.log('User menu clicked');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}