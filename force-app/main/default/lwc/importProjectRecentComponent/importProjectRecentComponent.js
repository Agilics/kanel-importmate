import { LightningElement, api, track } from "lwc";
import searchProjetById from "@salesforce/apex/ImportProjectController.searchProjetById";
// importation du modal
import DetailView from "c/projectDetailViewComponent";

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

  //Affichage  détail d'un projet importé via le modal DetailViewComponent
  async handleShowDetails(event) {
    //recherche le project via son id
    searchProjetById({ id: event.target.dataset.id })
      .then((result) => {
        return DetailView.open({
          size: "medium",
          description: "Détail du projet",
          project: result
        });
      })
      .catch((err) => {
        console.error("Erreur Apex:", err);
      });
  }

  //fermeture la section projets récents et on affiche la section création de projets
  openNewProject() {
    this.showCreatorSection = true;
  }

  //Dispatching vers le composant MainComponent
  // rechercher les projets importés par nom
  async handleShowSelectProject() {
    this.dispatchEvent(new CustomEvent("selectproject"));
  }


}