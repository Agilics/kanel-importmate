import { LightningElement, api, track } from "lwc";
import searchProjetsById from "@salesforce/apex/ImportProjectController.searchProjetsById";
export default class ImportProjectRecentComponent extends LightningElement {
  //params
  @api projects;
  @track projectId;
  @track projet; // check is project already imported
  get hasNoProjects() {
    return !(this.projects.data && this.projects.data.length > 0);
  } //on ferme la section projets recents et on affiche la section création de projet
  handleShow() {
    this.dispatchEvent(new CustomEvent("show"));
  }
  showModalBox() {
    this.isShowModal = true;
  }
  hideModalBox() {
    this.isShowModal = false;
  }
  //Affichage détail d'un projet importé via le modal SelectProjectComponent
  async handleShowDetails(event) {
    this.projectId = event.target.dataset.id;
    searchProjetsById({ id: this.projectId })
      .then((result) => {
        console.log("Résultat brut Apex:", result);
        this.project = result;
        this.isShowModal = true;
        /*return SelectProject.open({
          size: "large",
          description: "Détail du projet",
          content: { content: result }
        });*/
      })
      .then(() => {
        console.log("Projet affiché:", this.project);
        //   alert(JSON.stringify(this.project));
      })
      .catch((err) => {
        console.error("Erreur Apex:", err);
        //  alert(err.body ? err.body.message : err);
      }); /*try { const result = await searchProjetsById({ id: this.projectId }); 
      this.project = result; await SelectProjectComponent.open({ size: "large", description: "Détail du projet", content: { project: this.project } // passer via content }); } catch (error) { console.error('Erreur Apex:', error); }*/
  } //fermeture la section projets récents et on affiche la section création de projets
  openNewProject() {
    this.showCreatorSection = true;
  }
}
