/**
 * @author : Mouhamed NIANG
 * @date : 28/01/2026 
 * @description : This component is used to display the transformations of a project
 * @Modification : 
 *  - modified the handleAddTransformation method to refresh the list of transformations 
 *  - add the handleEditTransformation method to refresh the list of transformations 
 */
import { LightningElement, api, wire, track } from "lwc";
import TransformationModal from 'c/transformationSaveModal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchProjetById from '@salesforce/apex/ImportProjectController.searchProjetById'; 
import getRulesByProjectId from "@salesforce/apex/TransformationController.getRulesByProjectId";
import deleteTransformationById from "@salesforce/apex/TransformationController.deleteTransformationById";

import { refreshApex } from '@salesforce/apex';
const DEFAULT_PAGE_SIZE = 4;

export default class TransformationPage extends LightningElement {
  isWarningBadge = true;
  @api projectId; 
  @wire(searchProjetById, { projectId: "$projectId" }) selectedProject; 
  @track transformationsByMappingId = [];
  wiredTransformationResults =[]; // données affichées
  _wiredResult; //  résultat du @wire (OBLIGATOIRE pour refreshApex)
  @track mappingId;
  @track showMappings = false; 
  
   // ===== Pagination =====
  pageIndex = 1;
  pageSize = DEFAULT_PAGE_SIZE;
  
  // Paramètre du filtre de transformations
  activeTransformationTab = "all";
  
  //récupèrer toutes les transformations liés à un projet
  @wire(getRulesByProjectId, { projectId: '$projectId' })
  wiredTransformations(result) {
    this._wiredResult = result;

    const { error, data } = result;

    if (data) {
        this.wiredTransformationResults = data.map(rule => {
            const iconConfig = this.getIconConfig(rule.RuleType__c);
            const category = this.getCategory(rule.RuleType__c); 
            return {
                id: rule.Id,
                rule: rule.RuleType__c,
                category,
                displayTitle: iconConfig.title ?? rule.RuleType__c,
                displaySubtitle: `Source : ${rule.FieldMapping__r.SourceColumn__c ?? 'Unknown Field'} → ${rule.FieldMapping__r?.TargetField__c ?? 'Unknown Field'}`,
                iconName: iconConfig.icon,
                iconBoxClass: iconConfig.boxClass,
                headIconClass: iconConfig.iconClass,
                formattedRules: this.formatRuleContent(rule)
            };
        });
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
    if (!this.wiredTransformationResults) return [];

    if (this.activeTransformationTab === 'all') {
        return this.wiredTransformationResults;
    }

    return this.wiredTransformationResults.filter(
        t => t.category === this.activeTransformationTab
    );
  }


  //récupèrer le total des transformations filtrées
  get pagedTransformations() {
    const start = (this.pageIndex - 1) * this.pageSize;
    const end = start + this.pageSize;
    return this.filteredTransformations.slice(start, end);
  }


  // Ouverture du modal pour ajouter  une nouvelle transformation
  async handleAddTransformation(event) {  
    try {
      const result = await TransformationModal.open({ 
        size: 'large',
        description: 'Ce modal permet la création & la modification de nouvelle règle transformation avec les mappings',
        projectId: this.projectId,
        targetObject: this.selectedProject?.data?.TargetObject__c, 
        mappingId: event.detail.mappingId,
        mapping: event.detail.mapping,
        isEdit: false,

      });

       if (!result) return;

        if (result.success) {
            await refreshApex(this._wiredResult);
            this.showToast('Success', result.message, 'success');
          } else {
            this.showToast(
              result.variant === 'error' ? 'Error' : 'Warning',
              result.message || 'Update cancelled',
              result.variant || 'warning'
            );
          }
    } catch (error) {
      console.error('Erreur lors de la création:', error);
         this.showToast(
            'Error',
            error.message || 'Error creating rule',
            'error'
        );
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
    this.pageIndex = 1; // réinitialisation de l'index
  }

  resetPaginationIfNeeded() {
    const total = this.filteredTransformations.length;
    const maxPage = Math.max(1, Math.ceil(total / this.pageSize));

    if (this.pageIndex > maxPage) {
      this.pageIndex = maxPage;
    }
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

  handlePageChange(event) {
    const { pageIndex, showingFrom, showingTo } = event.detail;
    this.pageIndex = pageIndex;
    this.showingFrom = showingFrom;
    this.showingTo = showingTo;
  }

  async handleEditTransformation(event) {
    try {
      const existingRuleId = event.detail.ruleId; 
      console.log('existingRuleId', existingRuleId);
      const result = await TransformationModal.open({
        size: 'large',
        description: 'Ce modal permet la création et modification de règle transformation avec les mappings',
        projectId: this.projectId,
        targetObject: this.selectedProject?.data?.TargetObject__c,
        mappingId: event.detail.mappingId,
        mapping: event.detail.mapping,
        isEdit: event.detail.isEdit,
        existingRuleId: existingRuleId
      });

      if (!result) return;

      if (result.success) {
        await refreshApex(this._wiredResult);

        this.showToast(
          'Success',
           result.message,
          'success'
        );
      } else {
        this.showToast(
          'Warning',
          result.message,
          result.variant || 'warning'
        );
      }
    } catch (error) {
      console.error('Erreur lors de la création:', error);
      this.showToast(
        'Error',
        error.message || 'Error creating rule',
        'error'
      );
    }
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
      await refreshApex(this._wiredResult);

      this.resetPaginationIfNeeded(); //refresh pagination

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
    return this.wiredTransformationResults?.length > 0;
  }

  get hasTransformations() { 
    return this.filteredTransformations.length > 0;
  }

  // Afficher un toast
  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
