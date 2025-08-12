import { LightningElement, wire, api } from "lwc";
import getRecentsProjets from "@salesforce/apex/Namespace.ImportProjectController.getRecentsProjets";
export default class MainComponent extends LightningElement {
  @api limitor = 3;

  @wire(getRecentsProjets, { limitor: "$limitor" }) projects; //3 latest import projects

  //check is project already imported

  connectedCallback() {}
}
