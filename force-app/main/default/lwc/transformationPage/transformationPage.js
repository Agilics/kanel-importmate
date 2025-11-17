import { LightningElement, track } from "lwc";
//importation du modal TransformationModal pour la création de transformation
import TransformationModal from 'c/transformationSaveFormModal';

export default class TransformationPage extends LightningElement {
  isWarningBadge = true; // affiche du badge warning
  // paramètre de mappings
  mappings = [
    { Id:1, label:'"new" → "New"' },
    { Id:2, label:'"contacted" → "Working - Contacted"' },
    { Id:3, label:'"qualified" → "Qualified"' },
    { Id:4, label:'"Default → "Unqualified"' },
  ];
  
  //paramètre pour vérifier si c'est la section lead status
  isLeadStatus =true;
  

  // Paramètre du filtre de transformations
  @track activeTransformationTab = "all";

  // Getters pour déterminer quel onglet est actif
  get isAll() {
    return this.activeTransformationTab === "all";
  }

  get isBoolean() {
    return this.activeTransformationTab === "boolean";
  }

  get isCase() {
    return this.activeTransformationTab === "case";
  }

  get isMask() {
    return this.activeTransformationTab === "mask";
  }
  // ajout d'une nouvelle transformation à travers un modal
  async handleAddTransformation() { 
        const result = await TransformationModal.open({ 
            size: 'large',
            description: 'Ce modal permet la création de nouvelle transformation',
        });
        // if modal closed with X button, promise returns result = 'undefined'
        // if modal closed with OK button, promise returns result = 'okay'
        console.log(result);
  }
  

  // Gestion du changement d'onglets de transformation
  handleTransformationChange(event) {
    this.activeTransformationTab = event.detail.activetab;
    console.log("Onglet actif:", this.activeTransformationTab);
  }

  // Paramètre de contenu carte de transformation de l'email
  emailTransformationsRulesContent = [
    { Id: 1, label: "Convert to lowercase" },
    { Id: 2, label: "Validate email format" },
    { Id: 3, label: "Remove extra whitespace" }
  ];
  emailCardHeaderTitle = "Email Validation & Format";
  emailCardHeaderSubtitle = " Source: email_address → Target: Email";

  // Paramètre de contenu carte de transformation de numéro de téléphone
  phoneTransformationsRulesContent = [
    { Id: 1, label: "Remove non-numeric characters" },
    { Id: 2, label: "Format as (XXX) XXX-XXXX" },
    { Id: 3, label: "Add +1 prefix if missing" }
  ];
  phoneCardHeaderTitle = "Phone Number Formatting";
  phoneCardHeaderSubtitle = "Source: phone → Target: Phone";

  // Paramètre de contenu carte de transformation du lead
  leadTransformationsRulesContent = [
    { Id: 1, label: "Standardize status values" },
    { Id: 2, label: "Map custom status to standard" },
    { Id: 3, label: "Validate lead source" }
  ];
  leadCardHeaderTitle = "Lead Status Value Mapping";
  leadCardHeaderSubtitle = "Source: status → Target: Status";

  // Paramètre de contenu carte de transformation de date
  dateTransformationsRulesContent = [
    { Id: 1, label: "Convert to ISO format" },
    { Id: 2, label: "Handle timezone conversion" },
    { Id: 3, label: "Validate date ranges" }
  ];
  dateCardHeaderTitle = "Date Format Conversion";
  dateCardHeaderSubtitle = "Source: created_date → Target: CreatedDate";

  // Configuration des icônes Email
  get iconEmailClass() {
    return "icon is-centered custom-icon-email";
  }

  get iconEmailName() {
    return "utility:email";
  }

  get emailBoxIcon() {
    return "box-icon is-centered  email-card-icon-box";
  }

  // Configuration des icônes Téléphone - CORRIGÉ
  get iconPhoneNumberClass() {
    return "custom-icon-call";
  }

  get iconPhoneNumberName() {
    return "utility:call";
  }

  get phoneBoxIcon() {
    return "box-icon is-centered phone-card-icon-box";  
  }

  // Configuration des icônes Lead
  get iconLeadClass() {
    return "custom-icon-product_transfer";
  }

  get iconLeadName() {
    return "utility:product_transfer";
  }

  get leadBoxIcon() {
    return "box-icon is-centered lead-card-icon-box";
  }

  // Configuration des icônes Date
  get iconDateClass() {
    return "custom-icon-date_input";
  }

  get iconDateName() {
    return "utility:date_input";
  }

  get dateBoxIcon() {
    return "box-icon is-centered date-card-icon-box";
  }
}