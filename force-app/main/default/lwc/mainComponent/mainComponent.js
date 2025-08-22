import { LightningElement, wire, api } from "lwc";
import getRecentsProjets from "@salesforce/apex/ImportProjectController.getRecentsProjets";

export default class MainComponent extends LightningElement {
  @api limitor = 3;

  @wire(getRecentsProjets, { limitor: "$limitor" }) importProjects; // 3 latest import projects
}
