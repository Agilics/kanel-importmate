/**
 * @Last Modification by: Mouhamed
 * @Last Modification DATE : 02-20-2026
 * @Modification: Add i18n  custom labels
 */
import { LightningElement, api, track } from "lwc";
import LOCALE from "@salesforce/i18n/locale";

//import custom labels
 
import PROJECT_RECENT_NAME from '@salesforce/label/c.ProjectRecent_Name';
import PROJECT_RECENT_DESCRIPTION from '@salesforce/label/c.ProjectRecent_Description';
import PROJECT_RECENT_TARGET_OBJECT from '@salesforce/label/c.ProjectRecent_Target_Object';
import PROJECT_RECENT_TITLE from '@salesforce/label/c.ProjectRecent_Title';
import PROJECT_RECENT_USE_EXISTING from '@salesforce/label/c.ProjectRecent_Use_Existing';
import PROJECT_RECENT_USE_EXISTING_DESC from '@salesforce/label/c.ProjectRecent_Use_Existing_Description';
import PROJECT_RECENT_RECENT_PROJECTS from '@salesforce/label/c.ProjectRecent_Recent_Projects';
import PROJECT_RECENT_NO_PROJECT from '@salesforce/label/c.ProjectRecent_No_Project';
import PROJECT_RECENT_SELECT_PROJECT from '@salesforce/label/c.ProjectRecent_Select_Project';
import PROJECT_RECENT_TARGET_SOBJECT from '@salesforce/label/c.ProjectRecent_Target_SObject';
import PROJECT_RECENT_CREATED_LABEL from '@salesforce/label/c.ProjectRecent_Created_Label';

export default class ImportProjectRecentComponent extends LightningElement {
  //params
  @api projects;
  @api recentProject;
  @api projectId;
  @track selectedProject;

  /* Expose labels to template */
    labels = { 
        PROJECT_RECENT_TITLE,
        PROJECT_RECENT_USE_EXISTING,
        PROJECT_RECENT_USE_EXISTING_DESC,
        PROJECT_RECENT_RECENT_PROJECTS,
        PROJECT_RECENT_NO_PROJECT,
        PROJECT_RECENT_SELECT_PROJECT,
        PROJECT_RECENT_TARGET_SOBJECT,
        PROJECT_RECENT_CREATED_LABEL
    };

  //colonnes de la liste
  columns = [
    { label: PROJECT_RECENT_NAME, fieldName: "name" },
    { label: PROJECT_RECENT_TARGET_OBJECT, fieldName: "targetObject" },
    { label: PROJECT_RECENT_DESCRIPTION, fieldName: "description" },
    { label: "Actions", fieldName: "show" }
  ];

  // vérification si le projet est présent
  @api
  get hasNoProjects() {
    return !(this.projects?.data && this.projects?.data.length > 0);
  }

  //formattage de la date de modification
  get formattedProjects() {
    if (!this.projects?.data) return [];

    const formatter = new Intl.DateTimeFormat(LOCALE, {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    });

    return this.projects.data.map(p => {
      const raw = p.LastModifiedDate?.value;
      const date = raw ? new Date(raw) : null;

      return {
        ...p,
        formattedDate: date && !isNaN(date) ? formatter.format(date) : '—'
      };
    });
  }

  //on ferme la section projets recents et on affiche la section création de projet
  handleShow() {
    this.dispatchEvent(new CustomEvent("show"));
  }

  //fermeture la section projets récents et on affiche la section création de projets
  openNewProject() {
    this.showCreatorSection = true;
  }

  //Dispatching vers le composant MainComponent
  // rechercher les projets importés par nom
  async handleShowSelectProject(event) {
    const projectId = event.target.dataset.id; // on récupère l'id du projet sélectionné
    //bubbles: true permet à l’événement de remonter jusqu’au mainComponent même s’il est dans plusieurs couches de composants
    this.dispatchEvent(
      new CustomEvent("selectproject", { detail: projectId, bubbles: true })
    );
  }

  async handleFindExistingProject() {
    this.dispatchEvent(new CustomEvent("searchproject"));
  }
}