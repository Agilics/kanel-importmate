import { LightningElement, api } from "lwc";

export default class TransformationFieldTabs extends LightningElement {
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
    const value = event.target.dataset.value;
    // Le parent met à jour son state  du composant fieldTransformationTabs via le binding 
    this.dispatchEvent(
        new CustomEvent("movetransformation",
          {
            detail: {activetab: value}
          }
        )
      );
  }
}
