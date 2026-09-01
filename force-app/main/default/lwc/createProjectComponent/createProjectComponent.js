import { LightningElement, api, track } from "lwc";

//import methods from Controller
import getCompatibleSObjects from "@salesforce/apex/ImportProjectController.getCompatibleSObjects";

// Objets suggérés en accès rapide (pill grid)
const QUICK_OBJECTS = ["Contact", "Account", "Lead", "Opportunity", "Case"];

export default class ProjectCreatorComponent extends LightningElement {
  @api projectName = "";
  @api description = "";
  @api targetObject = "";
  @api importMode = "Insert"; // Insert | Upsert | Update
  @track options = [];
  @api project;
  @api currentStep;

  // Recherche dans la pill grid
  @track objectSearch = "";

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

  // ── Pill grid helpers ──────────────────────────────────────────

  /**
   * Retourne les options filtrées pour la pill grid.
   * Si la recherche est vide, on affiche les QUICK_OBJECTS en premier,
   * puis le reste des options (sans doublon).
   */
  get filteredOptions() {
    const search = (this.objectSearch || "").toLowerCase().trim();
    let source;

    if (!search) {
      // Affiche les objets rapides en priorité
      const quickSet = new Set(QUICK_OBJECTS);
      const quickItems = QUICK_OBJECTS.map((name) => ({ label: name, value: name }));
      const rest = this.options.filter((o) => !quickSet.has(o.value));
      source = [...quickItems, ...rest];
    } else {
      source = this.options.filter((o) =>
        o.label.toLowerCase().includes(search)
      );
    }

    return source.map((o) => ({
      ...o,
      pillClass:
        "object-pill" + (o.value === this.targetObject ? " selected" : "")
    }));
  }

  handleObjectSearch(event) {
    this.objectSearch = event.target.value;
  }

  handlePillClick(event) {
    const value = event.currentTarget.dataset.value;
    this.targetObject = value;
    this.dispatchEvent(
      new CustomEvent("targetchange", { detail: value })
    );
  }

  // ── Mode d'import toggle cards ─────────────────────────────────

  get insertCardClass() {
    return "toggle-card" + (this.importMode === "Insert" ? " selected" : "");
  }
  get upsertCardClass() {
    return "toggle-card" + (this.importMode === "Upsert" ? " selected" : "");
  }
  get updateCardClass() {
    return "toggle-card" + (this.importMode === "Update" ? " selected" : "");
  }

  handleModeSelect(event) {
    const mode = event.currentTarget.dataset.mode;
    this.importMode = mode;
    this.dispatchEvent(
      new CustomEvent("modechange", { detail: mode })
    );
  }

  // ── Handlers existants (inchangés) ────────────────────────────

  //Vérifie si le champs d'objet ciblé est selectionnée
  @api
  get isTargetObjetSelected() {
    return this.targetObject != null && this.targetObject.split("").length > 0;
  }

  //Dispatching vers le composant principal MainComopnent
  //Evénement portant sur la mise à jour du nom du projet
  handleProjectNameChange(event) {
    this.dispatchEvent(
      new CustomEvent("namechange", { detail: event.target.value })
    );
  }

  //Dispatching vers le composant principal MainComopnent
  //  le événement portant sur la mise à jour de l'attribut description
  handleDescriptionChange(event) {
    this.dispatchEvent(
      new CustomEvent("descriptionchange", { detail: event.target.value })
    );
  }

  //Dispatching vers le composant parent MainComponent
  //  de l'événement portant sur la mise à jour de l'attribut target object
  handleTargetObjectChange(event) {
    this.dispatchEvent(
      new CustomEvent("targetchange", { detail: event.target.value })
    );
  }

  //Evénement portant sur l'enregistrement de projet
  //Dispatching vers le parent (composant principal) des variables Name | Description | Target Object | ImportMode
  handleCreateProject() {
    this.dispatchEvent(
      new CustomEvent("save", {
        detail: {
          projectName: this.projectName,
          description: this.description,
          targetObject: this.targetObject,
          importMode: this.importMode
        }
      })
    );
  }

  // réintialisation des valeurs de tous les champs  de textes | combo box
  @api
  resetFields() {
    this.objectSearch = "";
    this.importMode = "Insert";
    // reset valeurs UI
    this.template.querySelectorAll(".rounded-input").forEach((input) => {
      input.value = "";
    });
  }

  //Masquer la section de création de projets
  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }
}
