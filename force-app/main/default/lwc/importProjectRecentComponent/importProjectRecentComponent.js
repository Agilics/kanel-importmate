import { LightningElement, api, track } from "lwc";

export default class ImportProjectRecentComponent extends LightningElement {
  //params
  @api projects;
  @api recentProject;
  @api projectId;
  @track selectedProject;

  //colonnes de la liste
  columns = [
    { label: "Project Name", fieldName: "name" },
    { label: "Target object", fieldName: "targetObject" },
    { label: "Description", fieldName: "description" },
    { label: "Actions", fieldName: "show" }
  ];

  // vérification si le projet est présent
  @api
  get hasNoProjects() {
    return !(this.projects?.data && this.projects?.data.length > 0);
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