// projects.js
import { api, track, wire } from "lwc";
import LightningModal from "lightning/modal";

import searchProjectsByName from "@salesforce/apex/ImportProjectController.searchProjectsByName";
export default class SelectProjectComponent extends LightningModal {
  columns = [
    { fieldName:'ProjectName',label:'Project name',},
    {fieldName:'TargetObject',label:'Target object',},
    { fieldName:'Description',label:'Description',},
    { fieldName:'Actions',label:'Actions',}
  ];
  @api selectedProject;
  @api title;

  @track error;
  @track nom = "";
  @track projects =[];

  @wire(searchProjectsByName, { nom: "$nom" })
  wiredSearchProjectHandler({ error, data }) {
    if (data) {
      this.projects = [...data];
      console.log(this.projects);
      this.error = undefined;
    } else if (error) {
      this.error = error;
      console.log(error?.body?.message);
    }
  }
  @api
  get hasNoProjects() {
     return !(this.projects && this.projects.length > 0);
  }

  // recherche de projets par le nom
  @api
  handleSearch(e) {
    this.nom = e.target.value;
    searchProjectsByName({ name: this.nom }).then((result) => {
      this.projects = [...result]; 
    });
  }

  //on récupére l'id du projet choisie
  handleShowDetailProject(e) {
    const { id } = e.target.dataset;
    this.dispatchEvent(new CustomEvent("select", { detail: id }));
    this.close(id);
  }

  //fermeture du modal
  handleCloseModal() {
    this.close();
  }
}
