import { LightningElement, api, wire, track } from "lwc";
import TransformationModal from 'c/transformationSaveModal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchProjetById from '@salesforce/apex/ImportProjectController.searchProjetById'; 
import getRulesByProjectId from "@salesforce/apex/TransformationController.getRulesByProjectId";
import deleteTransformationById from "@salesforce/apex/TransformationController.deleteTransformationById";

import { refreshApex } from '@salesforce/apex';

export default class TransformationPage extends LightningElement {
  isWarningBadge = true;
  @api projectId; 
  @wire(searchProjetById, { projectId: "$projectId" }) selectedProject; 
  @track transformationsByMappingId = [];
  wiredTransformationResults; // données affichées
  _wiredResult; //  résultat du @wire (OBLIGATOIRE pour refreshApex)
  @track mappingId;
  @track showMappings = false;  
  
  // Paramètre du filtre de transformations
  activeTransformationTab = "all";
  
  //récupèrer toutes les transformations liés à un projet
  @wire(getRulesByProjectId, { projectId: '$projectId' })
  wiredTransformations(result) {
    this._wiredResult = result;

    const { error, data } = result;

    if (data) {
        console.log('Transformations reçues :', JSON.stringify(data));

        this.wiredTransformationResults = data.map(rule => {
            const iconConfig = this.getIconConfig(rule.RuleType__c);
            const category = this.getCategory(rule.RuleType__c);

            return {
                id: rule.Id,
                rule: rule.RuleType__c,
                category,
                displayTitle: iconConfig.title ?? rule.RuleType__c,
                displaySubtitle: `Source : ${rule.FieldMapping__r?.SourceColumn__c ?? 'Unknown Field'} → ${rule.FieldMapping__r?.TargetField__c ?? 'Unknown Field'}`,
                iconName: iconConfig.icon,
                iconBoxClass: iconConfig.boxClass,
                headIconClass: iconConfig.iconClass,
                formattedRules: this.formatRuleContent(rule)
            };
        });

        console.log('Transformations formatées :', this.wiredTransformationResults.length);
    }
    else if (error) {
        console.error('Erreur chargement transformations:', error);
        this.wiredTransformationResults = [];
        this.showToast(
            'Erreur',
            error?.body?.message || 'Erreur inconnue',
            'error'
        );
    }
  }

  // Catégoriser les transformations
  getCategory(ruleType) {
    if (!ruleType) return 'other';
    const t = ruleType.toLowerCase();
    if (t.includes('boolean')) return 'boolean';
    if (t.includes('upper') || t.includes('lower') || t.includes('concatenate') || t.includes('concatenation')) return 'case';
    if (t.includes('email') || t.includes('phone') || t.includes('mask')) return 'mask';
    return 'other';
  }

  // Filtrer les transformations selon l'onglet actif
  get filteredTransformations() {
    if (this.activeTransformationTab === 'all') {
      return this.wiredTransformationResults;
    }
    return this.wiredTransformationResults.filter(t => t.category === this.activeTransformationTab);
  }

  // Ouverture du modal pour ajouter une nouvelle transformation
  async handleAddTransformation(event) {  
    try {
      const result = await TransformationModal.open({ 
        size: 'large',
        description: 'Ce modal permet la création de nouvelle règle transformation avec les mappings',
        projectId: this.projectId,
        targetObject: this.selectedProject?.data?.TargetObject__c,
        label: 'Add New rule',
        mappingId: event.detail.mappingId,
        mapping: event.detail.mapping,
        onrefresh: () => this.refreshTransformations() // refresh list rule
      });

      this.transformationId = result;
      console.log(' Transformation créée avec ID:', this.transformationId);
      
    } catch (error) {
      console.error('Erreur lors de la création:', error);
      this.showToast('Erreur', 'Impossible de créer la transformation', 'error');
    }
  }

  async refreshTransformations() {
      if (this._wiredResult) {
          await refreshApex(this._wiredResult);
      }
  }

  // Navigation vers l'étape 5: Validation (Dry Run)
  handleNextStep() {
    this.dispatchEvent(
      new CustomEvent('next', {
        detail: { transformationId: this.transformationId }
      })
    );
  }

  // Navigation vers l'étape 3: Field Mapping  
  handlePrevious() {
    this.dispatchEvent(new CustomEvent("previous"));
  }

  // Gestion du changement d'onglets de transformation
  handleTransformationChange(event) {
    this.activeTransformationTab = event.detail.activetab; 
  }

  // Configuration des icônes
  getIconConfig(type) {
    switch(type) {
      case 'EmailMask':
        return {
          title: "Email Validation & Format",
          icon: 'utility:email',
          boxClass: 'box-icon is-centered email-card-icon-box',
          iconClass: 'icon is-centered custom-icon-email'
        };
      case 'PhoneMask':
        return {
          title: 'Phone Number Formatting',
          icon: 'utility:call',
          boxClass: 'box-icon is-centered phone-card-icon-box',
          iconClass: 'icon is-centered custom-icon-phone'
        };
      case 'Concatenation':
        return {
          title: 'Field Concatenation',
          icon: 'utility:merge',
          boxClass: 'box-icon is-centered lead-card-icon-box',
          iconClass: 'icon is-centered custom-icon-product_transfer'
        };
      case 'LowercaseTransformation':
        return {
          title: 'Lowercase Conversion',
          icon: 'utility:text',
          boxClass: 'box-icon is-centered lead-card-icon-box',
          iconClass: 'icon is-centered custom-icon-product_transfer'
        };
      case 'UppercaseTransformation':
        return {
          title: 'Uppercase Conversion',
          icon: 'utility:display_rich_text',
          boxClass: 'box-icon is-centered lead-card-icon-box',
          iconClass: 'icon is-centered custom-icon-product_transfer'
        };
      default:
        return {
          title: 'Boolean Transformation',
          icon: 'utility:settings',
          boxClass: 'box-icon is-centered lead-card-icon-box',
          iconClass: 'icon is-centered custom-icon-product_transfer'
        };
    }
  }

  // Formater le contenu des règles
  formatRuleContent(rule) {
    const parsed = rule.Parameters__c ? JSON.parse(rule.Parameters__c) : {};
    return Object.entries(parsed).map(([key, value]) => ({
      label: `${key}: ${value}`
    }));
  }

  // Récupérer l'icône du bouton
  get iconName() {
    return this.showMappings ? 'utility:add' : 'utility:hide';
  } 

  // Récupérer le texte du bouton
  get textButton() {
    return this.showMappings ? 'Add Rule' : 'Hide';
  }

  // Afficher/masquer la section mappings
  handleShowMappings() {
    this.showMappings = !this.showMappings;
    return this.showMappings;
  }

  // Retour au mapping
  handleBackToMapping() {
    this.dispatchEvent(new CustomEvent("previous"));
  }

  async handleTransformationDelete(event) {
    try { 
      const ruleId = event.detail; 
      /*eslint no-alert: "error"*/
      const isConfirm = confirm('Are you sure you want to delete this transformation? This action cannot be undone.');
      // Confirm deletion
      if (!isConfirm) {
          return;
      } 
      await deleteTransformationById({ transformationId: ruleId });
      await refreshApex(this._wiredResult); // ✅ correction

      // Show success toast
      this.dispatchEvent(new ShowToastEvent({
        title: 'Success',
        message: 'Transformation deleted successfully',
        variant: 'success'
      }));
      
    } catch (error) { 
        console.error('Error deleting transformation rule:', error);
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: error.body?.message || 'Error deleting rule',
            variant: 'error'
        }));
    }
  }

  // Vérifier s'il y a des transformations
  get isTransformation() { 
    return this.wiredTransformationResults;
  }

  // Afficher un toast
  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
