import { LightningElement, track, wire } from "lwc";
import getSchedulesByProjectName from "@salesforce/apex/ScheduleController.getSchedulesByProjectName";
import getSchedulesByExecutionStatus from "@salesforce/apex/ScheduleController.getSchedulesByExecutionStatus";

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
  @track projectName = "";
  @track schedules = [];
  @track selectedStatus = ""; // Status par défaut

  @wire(getSchedulesByExecutionStatus, { executionStatus: "$selectedStatus" })
  wiredSchedulesByStatus({ error, data }) {
    if (data) {
      this.schedules = data.map((sch) => ({
        //mapping entre les Objets de Salesforce et  la variable schedule
        id: sch.Id,
        name: sch.Name,
        project: sch.Project__r?.Name,
        target: sch.Project__r?.Target_Object__c,
        status: sch.ImportExecutions__r?.Status__c,
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

  //Récupérer la liste des planifications dans une tableau
  @wire(getSchedulesByProjectName, { projectName: "$projectName" })
  wireAllSchedulesByProjectName({ error, data }) {
    if (data) {
      //on récupère la liste de planifications par le nom du projet si le champs de recherche est vide il retourne 200 enregistrements de Planifications
      this.schedules = data.map((sch) => ({
        //mapping entre les Objets de Salesforce et  la variable schedule
        id: sch.Id,
        projectName: sch.Project__r?.Name,
        target: sch.Project__r?.Target_Object__c,
        status: sch.ImportExecutions__r?.Status__c, //Status d'éxécution
        nextRun: sch.NextRun__c,
        frequency: sch.Frequency__c,
        totalRecord: sch.ImportExecutions__r.TotalRecords__c,
        failRecord: sch.ImportExecutions__r.FailRecord__c,
        //on récupére le nom de l'icône sf en fonction du status d'éxécution
        iconAction:
          String.valueOf(sch.ImportExecutions__r.Status__c) === "Active"
            ? "utility:pause "
            : "utility:play",
        //on récupére la classe  css du badge en fonction du status d'éxécution
        badgeStatusClass:
          String.valueOf(sch.ImportExecutions__r.Status__c) === "Active"
            ? "status-badge active-status "
            : "status-badge paused-status",
        hasFailRecord:
          parseInt(sch.ImportExecutions__r.FailRecord__c) > 0 ? true : false
      }));
    } else if (error) {
      //en cas d'erreur on affiche un message dans un toast
      this.showToast("Error", error?.body?.message, "error");
    }
  }


  //calculer la date de la dernière éxécution qui est la diffèrence entre aujourd'hui et la fin de d'éxécution en datetime
  get lastExecution() {
    this.schedules.forEach((item) => {
      const today = Date.now();
      const end = new Date(item.ImportExecutions__r.EndTime__c);
      var days = this.calculateDays(end);
      var monthDiff = this.getMonthDifference(end, today);

      if (this.days < 1) {
        //convertir en en heures
        return parseInt(dateDifference / (1000 * 60 * 60)) + "\thours\tago";
      } else if (days < 7) {
        //convertir en semaine
        return (
          parseInt(dateDifference / (1000 * 60 * 60 * 24 * 7)) + "\tweeks\tago"
        );
      } else {
        //convertir en mois
        return parseInt(monthDiff) + "\tmonths\tago";
      }
    });
  }

  //mettre à jour le statut en cas de changement sur le champs de selection
  handleStatusChange(event) {
    this.selectedStatus = event.target.value;
  }
  //mettre à jour le nom du projet en cas de changement sur le champs de selection
  handleSearchFieldChange(event) {
    this.projectName = event.target.value;
  }

  //calculer la différence de mois entre deux dates  ou le nombre de semaines depuis la dernière éxécution
  getMonthDifference(d1, d2) {
    var months;
    months = (d2.getFullYear() - d1.getFullYear()) * 12;
    months -= d1.getMonth();
    months += d2.getMonth();
    return months <= 0 ? 0 : months;
  }

  // calculer le nombre de jours depuis la dernière éxécution
  calculateDays(endDate) {
    let today = Date.now();
    let end = new Date(endDate);
    let timeDifference = today - end;
    let daysDifference = timeDifference / (1000 * 3600 * 24);
    return daysDifference;
  }
}
