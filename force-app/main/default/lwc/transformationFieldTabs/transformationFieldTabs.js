import { LightningElement, api } from "lwc";
import LABEL_TAB_ALL from '@salesforce/label/c.IM_TR_Tab_AllFields';
import LABEL_TAB_BOOLEAN from '@salesforce/label/c.IM_TR_Tab_Boolean';
import LABEL_TAB_CASE from '@salesforce/label/c.IM_TR_Tab_Case';
import LABEL_TAB_MASK from '@salesforce/label/c.IM_TR_Tab_Mask';

export default class TransformationFieldTabs extends LightningElement {

  tabs = [
    { label: LABEL_TAB_ALL, value: "all", id: 1 },
    { label: LABEL_TAB_BOOLEAN, value: "boolean", id: 2 },
    { label: LABEL_TAB_CASE, value: "case", id: 3 },
    { label: LABEL_TAB_MASK, value: "mask", id: 4 }
  ];

  @api activeTab = "all";

  get computedTabs() {
    return this.tabs.map((tab) => ({
      ...tab,
      tabClass: tab.value === this.activeTab ? "tab active" : "tab"
    }));
  }

  handleTransformationChange(event) {
    const value = event.target.dataset.value;
    this.dispatchEvent(
      new CustomEvent("movetransformation", {
        detail: { activetab: value }
      })
    );
  }
}