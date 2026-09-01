import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import FIRST_NAME from '@salesforce/schema/User.FirstName';
import LAST_NAME  from '@salesforce/schema/User.LastName';
import FULL_NAME  from '@salesforce/schema/User.Name';

const USER_FIELDS = [FIRST_NAME, LAST_NAME, FULL_NAME];

export default class AppHeaderCmp extends LightningElement {
    @api currentPage = 'dashboard';

    @track dashboardClass  = 'active';
    @track newProjectClass = '';
    @track historyClass    = '';

    @wire(getRecord, { recordId: userId, fields: USER_FIELDS })
    currentUser;

    get userInitials() {
        const fn = getFieldValue(this.currentUser?.data, FIRST_NAME) || '';
        const ln = getFieldValue(this.currentUser?.data, LAST_NAME)  || '';
        const initials = (fn.charAt(0) + ln.charAt(0)).toUpperCase();
        return initials || '?';
    }

    get userFullName() {
        return getFieldValue(this.currentUser?.data, FULL_NAME) || '';
    }

    connectedCallback() {
        this.updateClasses();
    }

    @api
    set activePage(value) {
        this._activePage = value;
        this.currentPage = value || 'dashboard';
        this.updateClasses();
    }
    get activePage() {
        return this._activePage;
    }

    updateClasses() {
        this.dashboardClass  = this.currentPage === 'dashboard' ? 'active' : '';
        this.newProjectClass = this.currentPage === 'projects'  ? 'active' : '';
        this.historyClass    = this.currentPage === 'history'   ? 'active' : '';
    }

    handleNavigation(event) {
        const page = event.currentTarget.dataset.page;
        if (page) {
            this.currentPage = page;
            this.updateClasses();
            this.dispatchEvent(new CustomEvent('navigation', {
                detail: { page },
                bubbles: true,
                composed: true
            }));
        }
    }
}
