// selectProject.js
import { api } from "lwc";
import LightningModal from "lightning/modal";

export default class SelectProjectComponent extends LightningModal {
  @api projects;
  @api columns;

handleSearch(e) {
  const searchEvent = new CustomEvent("search", {
    detail: { name: e.target.value }
  });
  this.dispatchEvent(searchEvent);
}
  //on choisie de visualiser les détails d'un projet importé et on ferme le modal 
  handleSelectProject(e) {
    const { id } = e.target.dataset;
    this.dispatchEvent(new CustomEvent("select", { detail: id }));
    this.close(id);
    alert(id);
  }

  handleCloseModal() {
    this.close();
  }
}