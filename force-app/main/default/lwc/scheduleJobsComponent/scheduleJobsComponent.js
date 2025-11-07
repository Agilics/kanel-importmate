import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getSchedulesByProjectName from "@salesforce/apex/ScheduleController.getSchedulesByProjectName";
import getSchedulesByExecutionStatus from "@salesforce/apex/ScheduleController.getSchedulesByExecutionStatus";
import getPickListValues from "@salesforce/apex/ScheduleController.getPickListValues";
import STATUS_FIELD from "@salesforce/schema/ImportExecution__c.Status__c";
import IMPORTEXECUTION_OBJECT from "@salesforce/schema/Schedule__c";

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

  //filtrer les planifications associées aux éxécution importé par le statut
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
        lastExecute: this.getLastExecution(sch.ImportExecutions__r.EndTime),
        //on récupére la classe  css du badge en fonction du status d'éxécution
        badgeStatusClass:
          String.valueOf(sch.ImportExecutions__r.Status__c) === "Active"
            ? "status-badge active-status "
            : "status-badge paused-status",
        //vérifie si on a au moins un échec d'importation
        hasFailRecord:
          parseInt(sch.ImportExecutions__r.FailRecord__c) > 0 ? true : false
      }));
    } else if (error) {
      //en cas d'erreur on affiche un message dans un toast
      this.showToast("Error", error?.body?.message, "error");
    }
  }

  //Récupération des valeurs de la liste de sélection de Frequency__c(Daily | Weekly | Monthly)
  @wire(getPickListValues, {
    objectApiName: IMPORTEXECUTION_OBJECT.objectApiName,
    fieldApiName: STATUS_FIELD.fieldApiName
  })
  wiredPicklistValues({ error, data }) {
    if (data) {
      this.picklistValues = Object.entries(data).map(([label, value]) => ({
        label,
        value
      }));
      console.log(data);
    } else if (error) {
      console.error(
        "Erreur lors de la récupération des valeurs de picklist : ",
        error
      );
      this.showToast(
        "Error",
        error?.body?.message ||
          "Erreur lors de la récupération des valeurs des planifications",
        "error"
      );
    }
  }
  //calculer la date de la dernière éxécution qui est la diffèrence entre aujourd'hui et la fin de d'éxécution en datetime
  getLastExecution(endDate) {
    const today = Date.now();
    const end = new Date(endDate);

    var days = this.calculateDays(end);
    var weeks = this.getWeeksDifference(end);
    var monthDiff = this.getMonthDifference(this.end, this.today);

    if (this.days < 1) {
      //convertir en en heures
      return parseInt(this.days) + "\thours\tago";
    } else if (weeks > 1 || this.days > 7) {
      //convertir en semaine
      return parseInt(this.weeks) + "\tweeks\tago";
    } else {
      //convertir en mois
      return parseInt(this.monthDiff) + "\tmonths\tago";
    }
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

  //calculer la diffèrence de semaine entre aujourd'hui et la dernière date d'éxécution
  getWeeksDifference(dt1) {
    // Calculate the difference in milliseconds between dt2 and dt1
    var diff = (Date.now().getTime() - dt1.getTime()) / 1000;
    // Convert the difference from milliseconds to weeks by dividing it by the number of milliseconds in a week
    diff /= 60 * 60 * 24 * 7;
    // Return the absolute value of the rounded difference as the result
    return Math.abs(Math.round(diff));
  }

  // calculer le nombre de jours depuis la dernière éxécution
  calculateDays(endDate) {
    let today = Date.now();
    let end = new Date(endDate);
    let timeDifference = today - end;
    let daysDifference = timeDifference / (1000 * 3600 * 24);
    return daysDifference;
  }

  //affiche un flash message via un toast
    showToast(title, message, variant) {
      const event = new ShowToastEvent({
        title: title,
        message: message,
        variant: variant,
        mode: "dismissable"
      });
      this.dispatchEvent(event);
    }
}
