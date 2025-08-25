import { LightningElement, api } from "lwc";
import searchProjetsById from "@salesforce/apex/ImportProjectController.searchProjetsById";
// importation du modal
import SelectProject from "c/selectProjectComponent";

export default class ImportProjectRecentComponent extends LightningElement {
  //params
  @api projects;
  @api projectId;

  // check is project already imported
  get hasNoProjects() {
    return !(this.projects.data && this.projects.data.length > 0);
  }
  //on ferme la section projets recents et on affiche la section création de projet
  handleShow() {
    this.dispatchEvent(new CustomEvent("show"));
  }

  showModalBox() {
    this.isShowModal = true;
  }

  hideModalBox() {
    this.isShowModal = false;
  }

  //Affichage  détail d'un projet importé via le modal SelectProjectComponent
  async handleShowDetails(event) {
    searchProjetsById({ id: event.target.dataset.id })
      .then((result) => {
        return SelectProject.open({
          size: "large",
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
}
