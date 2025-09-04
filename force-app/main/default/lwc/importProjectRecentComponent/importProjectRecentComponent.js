<<<<<<< HEAD
import { LightningElement, api,track } from "lwc";
import searchProjetById from "@salesforce/apex/ImportProjectController.searchProjetById";
// importation du modal
import DetailView from "c/projectDetailViewComponent";
=======
import { LightningElement, api, wire, track } from "lwc";
import searchProjetById from "@salesforce/apex/ImportProjectController.searchProjetById";
import getAllProjects from "@salesforce/apex/ImportProjectController.getAllProjects";
import searchProjetsByName from "@salesforce/apex/ImportProjectController.searchProjetsByName";
// importation du modal
import DetailView from "c/projectDetailViewComponent";
import SelectProject from "c/selectProjectComponent";
>>>>>>> f83ef903b35e27bd75f90d9deb39df4dacde02da

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

  @wire(getAllProjects) allProjects; //récupèrer tous les projets

  searchedProjects = [];

  projectName = "";

  //colonnes de la liste
  columns = [
    { label: "Project Name", fieldName: "name" },
    { label: "Target object", fieldName: "targetObject" },
    { label: "Description", fieldName: "description" },
    { label: "Actions", fieldName: "show" }
  ];

  // check is project already imported
  get hasNoProjects() {
    return !(this.projects.data && this.projects.data.length > 0);
  }
  //on ferme la section projets recents et on affiche la section création de projet
  handleShow() {
    this.dispatchEvent(new CustomEvent("show"));
  }

  //Affichage  détail d'un projet importé via le modal DetailViewComponent
  async handleShowDetails(event) {
<<<<<<< HEAD
    //recherche le project via son id
    searchProjetById({ id: event.target.dataset.id })
      .then((result) => {
        return DetailView.open({
          size: "medium",
=======
    searchProjetById({ id: event.target.dataset.id })
      .then((result) => {
        return DetailView.open({
          size: "large",
>>>>>>> f83ef903b35e27bd75f90d9deb39df4dacde02da
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

<<<<<<< HEAD
  //Dispatching vers le composant MainComponent
  // rechercher les projets importés par nom
   async handleShowSelectProject(e) {
   this.dispatchEvent(new CustomEvent('selectproject'));
=======
  connectedCallBack() {
    this.fetchImportProject({ name: this.projectName });
  }

  //rechercher les projets importés par nom
  fetchImportProject(name) {
    //  console.log(JSON.stringify(allProjects.data))
    if (name == "") {
      this.searchedProjects = [...this.allProjects.data];
    } else {
      searchProjectsByName({ projectName: name })
        .then((result) => {
          this.selectedProject = [...result];
          console.log(JSON.stringify(result));
        })
        .catch((er) => {
          console.log(er?.body.message);
        });
    }
  }
  // rechercher projet  par le nom
  handleSearchProjectByName(name) {
    this.fetchImportProject(name);
  }

  //  Ouverture Modal permettant de selectionner des  projets
  async handleShowSelectProject() {
    //  console.log(JSON.stringify(this.allProjects.data));
    // this.searchedProjects = [...this.allProjects.data]
    this.fetchImportProject(this.projectName);
    console.log(JSON.stringify(this.searchedProjects));
    await SelectProject.open({
      size: "large",
      description: "modal permettant la recherche de projets importés",
      columns: this.columns,
      projects: this.searchedProjects,
      onsearch: (e) => {
        this.handleSearchProjectByName(e.detail.name); //  récupérer le nom depuis le modal
      },
      onselect: (e) => {
        this.handleShowDetails(e);
        alert("fu");
      }
    });
>>>>>>> f83ef903b35e27bd75f90d9deb39df4dacde02da
  }
}