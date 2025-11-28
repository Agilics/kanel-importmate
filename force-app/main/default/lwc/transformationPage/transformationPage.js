import { LightningElement,api, wire ,track} from "lwc";
//importation du modal TransformationModal pour la création de transformation
import TransformationModal from 'c/transformationSaveModal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchProjetById from '@salesforce/apex/ImportProjectController.searchProjetById';
import getRulesByMappingId from '@salesforce/apex/TransformationController.getRulesByMappingId';

export default class TransformationPage extends LightningElement {
  isWarningBadge = true; // affiche du badge warning
  @api projectId; 
  @api targetObject; 
  transformationsByMappingId = [];
  @track mappingId;
  @track showMappings = false;
  @api selectedVersion;
  
  // paramètre de mappings
  mappings = [
    { Id:1, label:'"new" → "New"' },
    { Id:2, label:'"contacted" → "Working - Contacted"' },
    { Id:3, label:'"qualified" → "Qualified"' },
    { Id:4, label:'"Default → "Unqualified"' },
  ];
  
  //paramètre pour vérifier si c'est la section lead status
  isLeadStatus =true;
  
  //récuperer les transformations par l'id du mapping 
  loadTransformations(mappingId,version) {
    if (!mappingId) {
        console.error('mappingId est undefined, impossible de charger les transformations');
        this.transformationsByMappingId = [];
        return;
    }

    getRulesByMappingId(mappingId)
        .then(data => {
            console.log('Transformations reçues :', JSON.stringify(data));

            this.transformationsByMappingId = data.map(rule => {
                const iconConfig = this.getIconConfig(rule.RuleType__c);

                return {
                    id: rule.Id,
                    displayTitle: iconConfig.title ?? rule.RuleType__c,
                    displaySubtitle: ` ${rule.FieldMapping__r?.SourceColumn__c?? 'Champ inconnu'}→ ${rule.FieldMapping__r?.TargetField__c ?? 'Champ inconnu'}`,
                    iconName: iconConfig.icon,
                    iconBoxClass: iconConfig.boxClass,
                    headIconClass: iconConfig.iconClass,
                    formattedRules: this.formatRuleContent(rule)
                };
            });
        })
        .catch(error => {
            console.error('Erreur chargement transformations:', error);
            this.transformationsByMappingId = [];
            this.showToast('Erreur', error?.body?.message || 'Erreur inconnue', 'error');
        });
  }






  // Paramètre du filtre de transformations
  activeTransformationTab = "all";
  
  //onglet de navigation suivant le rule type choisi sur le tab bar (ALL FIELDS | BOOLEAN TRANSFORMATION | CASE TRANSFORMATION | DATA MASK)
  get filteredTransformations() {
    if (this.activeTransformationTab === 'all') {
        return this.transformationsByMappingId;
    }

    return this.transformationsByMappingId.filter(t => {
        switch (this.activeTransformationTab) {
            case 'boolean':
                return t.RuleType__c === 'BooleanTransformation';
            case 'case':
                return t.RuleType__c === 'UppercaseTransformation'
                    || t.RuleType__c === 'LowercaseTransformation';
            case 'mask':
                return t.RuleType__c === 'EmailMask'
                    || t.RuleType__c === 'PhoneMask';
            default:
                return true;
        }
    });
  }

  
  // ajout d'une nouvelle transformation à travers un modal
  async handleAddTransformation(event) { 
     this.mappingId = event.detail.mappingId;
     const result = await TransformationModal.open({ 
            size: 'large',
            description: 'Ce modal permet la création de nouvelle règle transformation avec les mappings',
            projectId: this.projectId,
            targetObject:this.targetObject,
            label:'Add New rule',
            mappingId :event.detail.mappingId,
            mapping: event.detail.mapping
    }); 
    this.handleShowMappings();
    this.loadTransformations({mappingId:event.detail.mappingId}); //affichage des transformation via l'id du mapping 
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
// get emailCardHeaderSubtitle(){ return  `Source: ${} → Target: Email`};

  // Paramètre de contenu carte de transformation de numéro de téléphone
  phoneTransformationsRulesContent = [
    { Id: 1, label: "Remove non-numeric characters" },
    { Id: 2, label: "Format as (XXX) XXX-XXXX" },
    { Id: 3, label: "Add +1 prefix if missing" }
  ]; 
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
  getCssClasses(type) {
    switch (type) {
        case 'EmailMask':
            return {
                box: "box-icon is-centered email-card-icon-box",
                icon: "icon is-centered custom-icon-email"
            };
        case 'PhoneMask':
            return {
                box: "box-icon is-centered phone-card-icon-box",
                icon: "icon is-centered custom-icon-phone"
            };
        case 'Concatenation':
            return {
                box: "box-icon is-centered concat-card-icon-box",
                icon: "icon is-centered custom-icon-concat"
            };
        case 'UppercaseTransformation':
            return {
                box: "box-icon is-centered upper-card-icon-box",
                icon: "icon is-centered custom-icon-upper"
            };
        default:
            return {
                box: "box-icon is-centered default-card-icon-box",
                icon: "icon is-centered custom-icon-default"
            };
    }
  }

   
  getIconConfig(type) {
    switch(type) {
        case 'EmailMask':
            return {
                title : "Email Validation & Format",
                icon: 'utility:email',
                boxClass: 'box-icon is-centered email-card-icon-box',
                iconClass: 'icon is-centered custom-icon-email'
            };

        case 'PhoneMask':
            return {
                title:'Phone Number Formatting',
                icon: 'utility:phone_portrait',
                boxClass: 'box-icon is-centered phone-card-icon-box',
                iconClass: 'icon is-centered custom-icon-phone'
            };

        case 'Concatenation':
            return {
                icon: 'utility:merge',
                boxClass: 'box-icon is-centered lead-card-icon-box',
                iconClass: 'icon is-centered custom-icon-product_transfer'
            };

        case 'LowercaseTransformation':
            return {
                icon: 'utility:text',
                boxClass: 'box-icon is-centered lead-card-icon-box',
                iconClass: 'icon is-centered custom-icon-product_transfer'
            };

        default:
            return {
                icon: 'utility:settings',
                boxClass: 'box-icon is-centered lead-card-icon-box',
                iconClass: 'icon is-centered custom-icon-product_transfer'
            };
    }
    }

    
  formatRuleContent(rule) {
    const parsed = rule.Parameters__c ? JSON.parse(rule.Parameters__c) : {};

    return Object.entries(parsed).map(([key, value]) => ({
        label: `${key}: ${value}`
    }));
  }

  //récupèrer l'icône du bouton affichage section de transformation
  get iconName(){
    return this.showMappings  ? 'utility:add':'utility:hide';
  } 

  //réxupérer le texte du bouton affichage section de transformation
  get textButton(){
    return this.showMappings ? 'Add Rule': 'Hide'
  }

  //affichage de la section mappings vers la transformation
  handleShowMappings(){
    return this.showMappings = !this.showMappings;
  }

  handleBackToMapping(){
    this.dispatchEvent(new CustomEvent("previous"));
  }

  //récupérer la taille des transformations
  get isTransformation(){
    return this.transformationsByMappingId && this.transformationsByMappingId.data.length >0;
  }
     showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

}