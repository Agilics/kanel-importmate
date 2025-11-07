import { LightningElement, track, wire } from "lwc";
import SCHEDULE_OBJECT from "@salesforce/schema/Schedule__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import FREQUENCY_FIELD from "@salesforce/schema/Schedule__c.Frequency__c";
import getPickListValues from "@salesforce/apex/ScheduleController.getPickListValues";
export default class ScheduleCreatorComponent extends LightningElement {
  @track executionDate;
  @track projectId;
  @track nextRun;
  @track picklistValues = []; // liste of frequency  DAILY | WEEKLY | MONTHLY
  @track selectedFrequency = "Daily";
  @track showSchedule;

  //Récupération des valeurs de la liste de sélection de Frequency__c(Daily | Weekly | Monthly)
  @wire(getPickListValues, {
    objectApiName: SCHEDULE_OBJECT.objectApiName,
    fieldApiName: FREQUENCY_FIELD.fieldApiName
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

  //Mise à jour de la valeur de selectedFrequency
  handleFrequencyChange(event) {
    this.selectedFrequency = event.target.value;
  }

  //Mise à jour du champs de la date d'éxécution
  handleNextRunChange(event) {
    this.nextRun = event.target.value;
  }

  //Enregistrement  d'une nouvelle planification
  async handleAddSchedule(event) {
    //Récupération de l'id du projet sélectionné
    const id = this.recentProject?.Id;
    try {
      if (!this.selectedFrequency || !this.nextRun) {
        this.showToast("Warning", "All fields are required.", "warning");
        this.isLoading = false;
        return;
      }
      /**
       * Création d'une planification via la fréquence , l'id du project
       * et la date d'éxécution NextRun
       *  Création d'une tâche Apex
       */

      const result = await addSchedule({
        frequency: this.selectedFrequency,
        nextRun: this.nextRun,
        projectId: id
      }).then((data) => {
        //Affichage du message toast de succès
        this.showToast(
          "Success",
          `Schedule  with ID:\t${data}  created  successfully !`,
          "success"
        );

        this.resetFields(); // Réintialisation de tous les champs de texte | combo box
        //TODO envoyer un boolean pour refresh la liste
        //   this.showSchedule = event.detail;
        // return refreshApex(this.wiredSchedulesResult); //  refresh datatable
      });
    } catch (err) {
      //Affichage d'un toast de message d'erreur
      this.showToast(
        "Error",
        err?.body?.message || "An Error were occured while adding a schedule! ",
        "error"
      );
    }
    const show = true; // show datatable list
    this.dispatchEvent(new CustomEvent("add", { detail: { show } }));
  }

  //cancel all actions
  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }

  // réintialisation des valeurs de tous les champs  de textes | combo box
  resetFields() {
    // reset valeurs UI
    this.template.querySelectorAll(".rounded-input").forEach((input) => {
      input.value = "";
    });
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
