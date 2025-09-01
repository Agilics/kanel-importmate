import { api } from "lwc";
import LightningModal from "lightning/modal";
/* Modal for  Import Project  Detail view*/
export default class ProjectDetailViewComponent extends LightningModal {
  @api project;

  //Fermeture  du modal
  handleCloseModal() {
    this.close("okay");
  }
}