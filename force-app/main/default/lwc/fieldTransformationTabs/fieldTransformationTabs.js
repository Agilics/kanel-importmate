import { LightningElement, api } from "lwc";

export default class FieldTransformationTabs extends LightningElement {
  tabs = [
    { label: "All Fields", value: "all", id: 1 },
    { label: "Boolean Transformation", value: "boolean", id: 2 },
    { label: "Case Transformation", value: "case", id: 3 },
    { label: "Data Masking", value: "mask", id: 4 }
  ];

  @api activeTab = "all";

  // Getter qui calcule les classes pour chaque onglet
  get computedTabs() {
    return this.tabs.map((tab) => ({
      ...tab,
      tabClass: tab.value === this.activeTab ? "tab active" : "tab"
    }));
  }

  // Gestion du changement d'onglet
 handleTransformationChange(event) {
    // Le parent met à jour son state
    this.activeTransformationTab = event.detail.activetab;
    // du composant fieldTransformationTabs via le binding
    console.log("Onglet actif:", this.activeTransformationTab);
}
}
