/* Modal for select Import Project */
import { api } from "lwc";
import LightningModal from "lightning/modal";

export default class SelectProjectComponent extends LightningModal {
  //@api projectId;
  //@api projectName;
  @api project;

  columns = [
    { label: "Project Name", fieldName: "name" },
    { label: "Description", fieldName: "description" },
    { label: "Target Objet", fieldName: "target" }
  ];

  /*handleFindProjectById(event) {
    this.dispatchEvent(new new CustomEvent("findid")());
  }*/

  // rechercher projet  par le nom
  /**handleSearch(event) {
    this.dispatchEvent(new CustomEvent("search"));
  }*/

  //Fermeture  du modal
  handleCloseModal() {
    this.close("okay");
  }
}
