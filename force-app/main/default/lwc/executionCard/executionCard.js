/**
 * @Last Modification: 22-04-2026
 */
import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import SCHEDULE_OBJECT from "@salesforce/schema/Schedule__c"; 
import FREQUENCY_FIELD from "@salesforce/schema/Schedule__c.Frequency__c";
import getPickListValues from "@salesforce/apex/ScheduleController.getPickListValues";

import LABEL_TOAST_ERROR from '@salesforce/label/c.Toast_Title_Error';
import LABEL_ERR_LOAD_FREQUENCIES from '@salesforce/label/c.SCH_Creator_Err_LoadFrequencies';

//custom labels

import LABEL_IMMEDIATE_EXECUTION from '@salesforce/label/c.Import_ImmediateExecution'; 
import LABEL_INPUT_IMPORT_SCHEDULE_EXECUTION from '@salesforce/label/c.Import_ScheduledExecution';
import LABEL_INPUT_IMPORT_SET_UP_RECURRING_IMPORTs from '@salesforce/label/c.Import_ExecutionMode';
import LABEL_RUN_IMPORT_NOW from '@salesforce/label/c.Import_RunImportNow';
import LABEL_SCHEDULED_EXECUTION from '@salesforce/label/c.Import_ScheduledExecution';
import LABEL_SET_UP_RECURRING_IMPORTS from '@salesforce/label/c.Import_SetUpRecurringImports';
import LABEL_EXECUTION_MODE from '@salesforce/label/c.Import_ExecutionMode';
import LABEL_BATCH_SIZE from '@salesforce/label/c.Import_BatchSize';
import LABEL_SEND_EMAIL_NOTIFICATIONS from '@salesforce/label/c.Import_SendEmailNotificationsOnComplete';
import LABEL_FREQUENCY from '@salesforce/label/c.Import_Frequency';
import LABEL_START_DATE_AND_TIME from '@salesforce/label/c.Import_StartDateAndTime';  
import LABEL_SCHEDULED_IMPORTS_NOTE from '@salesforce/label/c.Import_ScheduledImportsNote';

export default class ExecutionCard extends LightningElement {
    @api showScheduledCard ;
    //paramètre des combo-box
    @api modeOptions;
    @api executionMode = '';
 
    @api batchSizeOptions;

    @api selectedFrequency='';
    frequencyOptions = [];

    @api nextRun;
    
    @api batchSize;


    // paramètre de personalisation des classes CSS de la card
    @api sendEmailNotification;
 
    //form styles
    @api formGroup;
    @api formLabel;


    get titleCard (){ 
        return this.showScheduledCard ? LABEL_SCHEDULED_EXECUTION:LABEL_IMMEDIATE_EXECUTION;
    }

    get subtitleCard (){
        return this.showScheduledCard ? LABEL_SET_UP_RECURRING_IMPORTS :LABEL_RUN_IMPORT_NOW ;
    }

    //labels
    get labels() {
        return {
            LABEL_INPUT_IMPORT_SCHEDULE_EXECUTION,
            LABEL_INPUT_IMPORT_SET_UP_RECURRING_IMPORTs,
            labelExecutionMode: LABEL_EXECUTION_MODE,
            labelBatchSize: LABEL_BATCH_SIZE,
            labelSendEmail: LABEL_SEND_EMAIL_NOTIFICATIONS,
            labelFrequency: LABEL_FREQUENCY,
            labelStartDate: LABEL_START_DATE_AND_TIME, 
            scheduledImportNote: LABEL_SCHEDULED_IMPORTS_NOTE
        };
    }

    //Récupération des valeurs de la liste de sélection de Frequency__c(Daily | Weekly | Monthly)
    @wire(getPickListValues, {
        objectApiName: SCHEDULE_OBJECT.objectApiName,
        fieldApiName: FREQUENCY_FIELD.fieldApiName
    })
    wiredPicklistValues({ error, data }) {
        if (data) {
          this.frequencyOptions = Object.entries(data).map(([label, value]) => ({
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
            LABEL_TOAST_ERROR,
            error?.body?.message || LABEL_ERR_LOAD_FREQUENCIES,
            "error"
          );
        }
    }
      
    // récupèrer la valeur du mode choisie dans le combobox
    handleModeChange(event) {
         this.dispatchEvent(
            new CustomEvent(
                "modechange",
                { detail: {value :event.target.value }}
            )
        );
    }

    // récupèrer la valeur du batch size choisie dans le combobox
    handleBatchSizeChange(event) {
       const selectedValue = event.target.value;
        this.dispatchEvent(
            new CustomEvent(
                "batchsizechange",
                { detail: {value: parseInt(selectedValue,10)}}
            )
        );
    }
    
    //Mise à jour de la valeur de selectedFrequency
    handleFrequencyChange(event) {
         this.dispatchEvent(
            new CustomEvent(
                "frequencychange",
                { detail: {value:event.target.value} }
            )
        );
    }

    
    //Mise à jour du champs de la date d'éxécution (Start)
    handleNextRunChange(event) {
        const date = event.target.value;
         this.dispatchEvent(
            new CustomEvent(
                "nextrunchange",
                { detail: {value:date} }

            )
        );
    }


    handleEmailNotificationChange(event) {
        this.dispatchEvent(
            new CustomEvent(
                "sendnotification",
                {
                    detail: event.target.checked 
                }
            )
        )
    }


   
    
    get iconClass(){
        return this.showScheduledCard ? ' custom-icon-calendar':'custom-icon-connected_apps';
    }

    //récupèrer le style css de la box icone
    get boxIconClass(){
        return this.showScheduledCard ? 'box-icon is-centered box-icon-scheduled' : 'is-centered box-icon box-icon-immediate';
    }

    
    //récupèrer le nom de l'icône
    get iconName(){
        return this.showScheduledCard ? 'utility:event': 'utility:connected_apps';
    }

    //récupère la taille de l'icône
    get iconSize(){
        return  !this.showScheduledCard  ? 'medium':'small';
    }


    // réintialisation des valeurs de tous les champs  de textes | combo box
    resetFields() {
    // reset valeurs UI
        this.template.querySelectorAll(".form-control").forEach((input) => {
         input.value = "";
        });
    }

    //affichage toast mesage 
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}