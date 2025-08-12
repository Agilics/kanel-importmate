import { LightningElement, wire } from "lwc";
import getRecentsProjets from "@salesforce/apex/Namespace.ImportProjectController.getRecentsProjets";
export default class MainComponent extends LightningElement {
  projects;

  @wire(getRecentsProjets) importProjects; //3 latest import projects

  //check is project already imported

  connectedCallback() {}
}
