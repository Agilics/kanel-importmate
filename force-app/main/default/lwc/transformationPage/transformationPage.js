import { LightningElement,api, wire ,track} from "lwc";
//importation du modal TransformationModal pour la création de transformation
import TransformationModal from 'c/transformationSaveModal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchProjetById from '@salesforce/apex/ImportProjectController.searchProjetById';
import getRulesByMappingId from '@salesforce/apex/TransformationController.getRulesByMappingId';


export default class TransformationPage extends LightningElement {
  isWarningBadge = true; // affiche du badge warning
  @api projectId; 
  @wire(searchProjetById, { projectId: "$projectId" }) selectedProject; 
  transformationsByMappingId = [];
  @track mappingId;
  @track showMappings = false; 
  @track transformationId;
  
   
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
                const category = this.getCategory(rule.RuleType__c);
                console.log(`source column : ${rule.FieldMapping__r?.SourceColumn__c}`)
                return {
                    id: rule.Id,
                    rule:rule?.RuleType__c,
                    category,       
                    displayTitle: iconConfig.title ?? rule.RuleType__c,
                    displaySubtitle: `Source : ${rule.FieldMapping__r?.SourceColumn__c ?? 'Unknown Field'} → ${rule.FieldMapping__r?.TargetField__c ?? 'Unknown Field'}`,
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
  // Ajoute cette fonction dans la classe
  getCategory(ruleType) {
    if (!ruleType) return 'other';
    const t = ruleType.toLowerCase();
    if (t.includes('boolean')) return 'boolean';
    if (t.includes('upper') || t.includes('lower') || t.includes('concatenate') || t.includes('concatenation')) return 'case';
    if (t.includes('email') || t.includes('phone') || t.includes('mask')) return 'mask';
    return 'other';
  }


  
  //onglet de navigation suivant le rule type choisi sur le tab bar (ALL FIELDS | BOOLEAN TRANSFORMATION | CASE TRANSFORMATION | DATA MASK)
   get filteredTransformations() {
      if (this.activeTransformationTab === 'all') {
        return this.transformationsByMappingId;
      }
      return this.transformationsByMappingId.filter(t => t.category === this.activeTransformationTab);
   }



  
  // Ouverture du modal permettant ajouter une nouvelle transformation
  async handleAddTransformation(event) { 
     this.mappingId = event.detail.mappingId;
     const result = await TransformationModal.open({ 
            size: 'large',
            description: 'Ce modal permet la création de nouvelle règle transformation avec les mappings',
            projectId: this.projectId,
            targetObject: this.selectedProject?.data?.TargetObject__c,
            label:'Add New rule',
            mappingId :event.detail.mappingId,
            mapping: event.detail.mapping
    }).then((ruleId)=>{
        this.transformationId = ruleId; // on récupère l'id de la transformation  à la fermeture du modal
      }); 
    this.handleShowMappings();
    this.loadTransformations({mappingId:event.detail.mappingId}); //affichage des transformation via l'id du mapping 
  }

  //navigation à vers l'étape 5: Validation (Dry Run)
  handleNextStep(event){
    this.dispatchEvent(
      new CustomEvent(
        'next',
        {
          detail: {transformationId:this.transformationId}
        }
      )
    );
  }

  //navigation vers l'étape 3 : (STEP 3) Field Mapping  
  handlePrevious(){
    this.dispatchEvent(new CustomEvent("previous"));
  }


  // Gestion du changement d'onglets de transformation
  handleTransformationChange(event) {
    this.activeTransformationTab = event.detail.activetab;
    console.log("Onglet actif:", this.activeTransformationTab);
  }

  
  // Configuration des  icônes box 
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

   // configuration nom des icônes, et des cartes des icônes et de leur contour (box)
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
                icon: 'utility:call',
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
        case 'UppercaseTransformation':
            return {
                icon: 'utility:display_rich_text',
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
    return this.transformationsByMappingId && this.transformationsByMappingId.length >0;
  }
     showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

}