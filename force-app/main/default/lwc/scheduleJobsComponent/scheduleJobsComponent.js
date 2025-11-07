import { LightningElement, track, wire } from "lwc";
import getSchedulesByProjectName from "@salesforce/apex/ScheduleController.getSchedulesByProjectName"; 
import getSchedulesByExecutionStatus from '@salesforce/apex/ScheduleController.getSchedulesByExecutionStatus';


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

  @track selectedStatus = ''; // Status par défaut

    @wire(getSchedulesByExecutionStatus, { executionStatus: '$selectedStatus' })
    wiredSchedules({ error, data }) {
        if (data) {
            this.schedules = .map((sch) => ({
          //mapping entre les Objets de Salesforce et  la variable schedule
          id: sch.Id,
          name: sch.Name,
          project: sch.Project__r?.Name,
          target: sch.Project__r?.Target_Object__c,
          status:sch.ImportExecutions__r?.Status__c,
          nextRun: sch.NextRun__c,
          frequency: sch.Frequency__c
        }));
            this.error = undefined;
        } else if (error) {
          this.error = error;
            //en cas d'erreur on affiche un message dans un toast
            this.showToast("Error", error?.body?.message, "error");
            this.schedules = [];
        }
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
    }

  //Récupérer la liste des planifications dans une tableau 
   @wire(getSchedulesByProjectName)
    wireAllSchedules(result) {
      this.schedules = result;
      const { data, error } = result;
     if (data) {
        //on récupère la liste de planifications par le nom du projet si le champs de recherche est vide il retourne 200 enregistrements de Planifications
       this.schedules = data.map((sch) => ({
          //mapping entre les Objets de Salesforce et  la variable schedule
          id: sch.Id,
          name: sch.Name,
          project: sch.Project__r?.Name,
          target: sch.Project__r?.Target_Object__c,
          status:sch.ImportExecutions__r?.Status__c, //Status d'éxécution
          nextRun: sch.NextRun__c,
          frequency: sch.Frequency__c
        }));
      } else if (error) {
        //en cas d'erreur on affiche un message dans un toast
        this.showToast("Error", error?.body?.message, "error");
      }
    }


  get jobStatusBadgeClass(){
  return  Status === 'Active' ?'status-badge active-status ':'status-badge paused-status';
  }
}
