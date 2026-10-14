/**
 * 
 * @Last Modification Date: 02-16-2025
 * @Modification: 
 * -   ajout I18n
 */
import { LightningElement, api, track } from "lwc";
//import methods from Controller
import getCompatibleSObjects from "@salesforce/apex/ImportProjectController.getCompatibleSObjects";
// Import des labels
import projectInfoLabel from "@salesforce/label/c.ProjectForm_Title";
import projectDetailsLabel from "@salesforce/label/c.ProjectForm_Subtitle";
import targetObjectInfoLabel from "@salesforce/label/c.ProjectForm_Target_Section_Label";
import projectNameLabel from "@salesforce/label/c.ProjectForm_Name";
import descriptionLabel from "@salesforce/label/c.ProjectForm_Description"; 
import projectInfoSectionLabel from "@salesforce/label/c.ProjectForm_Info_Section_Label";
import targetObjectLabel from "@salesforce/label/c.ProjectForm_Target_Object";
//helper text labels
import helperNameLabel from "@salesforce/label/c.ProjectForm_Helper_Name";
import helperDescriptionLabel from "@salesforce/label/c.ProjectForm_Helper_Description";
import helpertargetObjectLabel from "@salesforce/label/c.ProjectForm_Helper_Target_Object";

//placeholder
import NAME_PLACEHOLDER from '@salesforce/label/c.ImportProject_Name_Placeholder';
import DESCRIPTION_PLACEHOLDER from '@salesforce/label/c.ImportProject_Description_Placeholder';
export default class ProjectFormComponent extends LightningElement {
  @api projectName = "";
  @api description = "";
  @api targetObject = "";
  @track options = [];
  @api project;
  @api currentStep;
  @api openModal = false; //affichage modal pour une modification

  label = { 
    projectDetailsLabel,
    projectInfoSectionLabel,
    projectNameLabel,
    descriptionLabel,
    targetObjectLabel,
    projectInfoLabel,
    projectDetailsLabel,
    targetObjectInfoLabel,
    helperNameLabel,
    helperDescriptionLabel,
    helpertargetObjectLabel,
 
  };

  descriptionPlaceholder = DESCRIPTION_PLACEHOLDER;
  projectNamePlaceholder = NAME_PLACEHOLDER;

  // Permet au parent de définir des valeurs initiales dans le champs target object
  connectedCallback() {
    getCompatibleSObjects()
      .then((results) => {
        if (results && results.length > 0) {
          // Transformer la liste en [{label, value}]
          this.options = results.map((objName) => {
            return { label: objName, value: objName };
          });
        }
      })
      .catch((e) => {
        console.error(
          "Erreur lors de la récupération des objets:",
          e?.body?.message || e
        );
      });
  }

  get targetObjectOptionsWithSelected() {
    return (this.options || []).map(o => ({ ...o, isSelected: o.value === this.targetObject }));
  }

  get isNoTargetSelected() {
    return !this.targetObject;
  }

  //Vérifie si le champs d'objet ciblé est selectionnée
  @api
  get isTargetObjetSelected() {
    return this.targetObject != null && this.targetObject.split("").length > 0;
  }

  //Dispatching vers le composant principal MainComopnent
  //Evénement portant sur la mise à jour du nom du projet
  handleProjectNameChange(event) {
    this.projectName = event.target.value;
    this.dispatchEvent(
      new CustomEvent("projectnamechange", { detail: event.target.value })
    );
  }

  //Dispatching vers le composant principal MainComopnent
  //  le événement portant sur la mise à jour de l'attribut description
  handleDescriptionChange(event) {
    this.description = event.target.value;
    this.dispatchEvent(
      new CustomEvent("descriptionchange", { detail: event.target.value })
    );
  }

  //Dispatching vers le composant parent MainComponent
  //  de l'événement portant sur la mise à jour de l'attribut target object
  handleTargetObjectChange(event) {
    this.targetObject = event.target.value;
    this.dispatchEvent(
      new CustomEvent("targetobjectchange", { detail: event.target.value })
    );
  }

  //Evénement portant sur l'enregistrement de projet
  //Dispatching vers le parent (composant principal) des variables Name | Description | Target Object
  handleCreateProject() {
    this.dispatchEvent(
      new CustomEvent("save", {
        detail: {
          projectName: this.projectName,
          description: this.description,
          targetObject: this.targetObject
        }
      })
    );
  }

  // réintialisation des valeurs de tous les champs  de textes | combo box
  @api
  resetFields() {
    // Réinitialiser les propriétés (source de vérité côté enfant)
    this.projectName = "";
    this.description = "";
    this.targetObject = "";

    // Réinitialiser les champs visuels (classe CSS correcte)
    this.template.querySelectorAll(".form-input").forEach((input) => {
      input.value = "";
    });

    // Réinitialiser aussi l'ancien sélecteur pour compatibilité
    this.template.querySelectorAll(".rounded-input").forEach((input) => {
      input.value = "";
    });
  }

  // classe css 
  get containerClass(){
    return this.openModal ? '':'main-content';
  }

  get contentClass(){
    return this.openModal ? 'model-padding':'card';
  }

  //Masquer la section de création de projets
  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }
}