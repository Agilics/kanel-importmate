import { LightningElement, api } from "lwc";

export default class ImportProjectRecentComponent extends LightningElement {
  @api projects;

  // check is project already imported
   get hasNoProjects() {
        return !( this.projects.data && this.projects.data.lenght > 0);
    }
}
