// projects.js
import { api, track, wire } from "lwc";
import LightningModal from "lightning/modal";

import searchProjectsByName from "@salesforce/apex/ImportProjectController.searchProjectsByName";
export default class SelectProjectComponent extends LightningModal {
  @api columns;
  @api selectedProject;

  @track error;
  @track nom = "";
  @track projects = [];
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

  // recherche de projets par le nom
  handleSearch(e) {
    this.nom = e.target.value;
    searchProjectsByName({ name: this.nom }).then((result) => {
      this.projects = [...result];
      console.log("new value:" + JSON.stringify(this.projects));
    });
  }
  //on récupére l'id du projet choisie
  handleShowDetailProject(e) {
    const { id } = e.target.dataset;
    this.dispatchEvent(new CustomEvent("select", { detail: id }));
    this.close(id);
  }

  handleCloseModal() {
    this.close();
  }
}
