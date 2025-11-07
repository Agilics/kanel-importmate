import { LightningElement ,track,wire} from "lwc";

export default class ScheduleJobsComponent extends LightningElement {
  //schedule jobs list table name
  columns = [
    { label: "Project", fieldName: "project" },
    { label: "Frequency", fieldName: "frequency" },
    { label: "Next Run", fieldName: "nextRun", type: "date" },
    { label: "Last Execution", fieldName: "lastExecution" },
    { label: "Status", fieldName: "status" },
    { label: "Actions", fieldName: "actions" }
  ];
  
  @track schedules = [];
}
