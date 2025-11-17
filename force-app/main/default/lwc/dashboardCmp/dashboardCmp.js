import { LightningElement, track, wire } from "lwc";
import getDashboardData from "@salesforce/apex/DashboardController.getDashboardData";
import deleteProject from "@salesforce/apex/DashboardController.deleteProject";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { navigateToPage } from "c/utility";

export default class DashboardCmp extends LightningElement {
  @track stats = [];

  @track filterTabs = [
    { label: "All Projects", value: "all", active: true },
    { label: "Active", value: "active", active: false },
    { label: "Completed", value: "completed", active: false },
    { label: "Scheduled", value: "scheduled", active: false }
  ];

  @track projects = [];
  @track allProjects = [];
  @track isLoading = false;
  @track error;
  searchTerm = "";
  wiredDashboardResult;

  // Wire to get dashboard data
  @wire(getDashboardData, { limitor: 50 })
  wiredDashboard(result) {
    this.wiredDashboardResult = result;
    if (result.data) {
      // Process projects
      this.allProjects = result.data.projects || [];
      this.projects = [...this.allProjects];

      // Process stats
      if (result.data.stats) {
        this.stats = [
          {
            id: 1,
            label: "Total Projects",
            value: String(result.data.stats.totalProjects || 0),
            change: "",
            changeLabel: "",
            icon: "standard:folder",
            iconColor: "blue"
          },
          {
            id: 2,
            label: "Records Imported",
            value: result.data.stats.recordsImportedFormatted || "0",
            change: "",
            changeLabel: "",
            icon: "standard:data_integration_hub",
            iconColor: "green"
          },
          {
            id: 3,
            label: "Success Rate",
            value: result.data.stats.successRateFormatted || "0%",
            change: "",
            changeLabel: "",
            icon: "standard:approval",
            iconColor: "green"
          },
          {
            id: 4,
            label: "Active Projects",
            value: String(result.data.stats.activeSchedules || 0),
            change: "",
            changeLabel: "",
            icon: "standard:event",
            iconColor: "purple"
          }
        ];
      }

      this.isLoading = false;
      this.error = undefined;
    } else if (result.error) {
      this.error = result.error;
      this.projects = [];
      this.allProjects = [];
      this.stats = [];
      this.isLoading = false;
      console.error("Error loading dashboard data:", result.error);
    }
  }

  get hasProjects() {
    return this.projects && this.projects.length > 0;
  }

  get noProjectsMessage() {
    if (this.isLoading) {
      return "Loading projects...";
    }
    if (this.error) {
      return "Error loading projects. Please try again.";
    }
    return "No projects found. Create your first project to get started.";
  }

  handleSearch(event) {
    this.searchTerm = event.target.value.toLowerCase();
    this.filterProjects();
  }

  handleNewProject() {
    this.dispatchEvent(new CustomEvent("newproject"));
  }

  handleFilterChange(event) {
    const selectedValue = event.currentTarget.dataset.value;
    this.filterTabs = this.filterTabs.map((tab) => ({
      ...tab,
      active: tab.value === selectedValue
    }));
    this.filterProjects();
  }

  filterProjects() {
    const activeFilter =
      this.filterTabs.find((tab) => tab.active)?.value || "all";
    let filtered = [...this.allProjects];

    // Apply status filter
    if (activeFilter !== "all") {
      filtered = filtered.filter((project) => {
        // Récupérer le statut depuis la dernière exécution
        const lastExecution =
          project.ImportExecutions__r && project.ImportExecutions__r.length > 0
            ? project.ImportExecutions__r[0]
            : null;
        const status = (lastExecution?.Status__c || "").toLowerCase();

        // Mapper les statuts aux filtres
        if (activeFilter === "active") {
          return status === "inprogress" || status === "pending";
        } else if (activeFilter === "completed") {
          return status === "completed";
        } else if (activeFilter === "scheduled") {
          return status === "pending";
        }
        return false;
      });
    }

    // Apply search filter
    if (this.searchTerm) {
      filtered = filtered.filter((project) => {
        const name = (project.Name || "").toLowerCase();
        const target = (project.TargetObject__c || "").toLowerCase();
        const description = (project.Description__c || "").toLowerCase();
        return (
          name.includes(this.searchTerm) ||
          target.includes(this.searchTerm) ||
          description.includes(this.searchTerm)
        );
      });
    }

    this.projects = filtered;
  }

  handleProjectSelect(event) {
    const projectId = event.detail;
    this.dispatchEvent(
      new CustomEvent("projectselect", {
        detail: projectId
      })
    );
  }

  handleProjectEdit(event) {
    const projectId = event.detail;
    // Dispatch edit event to parent
    this.dispatchEvent(
      new CustomEvent("projectedit", {
        detail: projectId
      })
    );
  }

  async handleProjectDelete(event) {
    const projectId = event.detail;

    // Confirm deletion
    if (
      !confirm(
        "Are you sure you want to delete this project? This action cannot be undone."
      )
    ) {
      return;
    }

    try {
      this.isLoading = true;
      await deleteProject({ projectId: projectId });

      // Show success toast
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Project deleted successfully",
          variant: "success"
        })
      );

      // Refresh dashboard data
      await this.refreshDashboard();
    } catch (error) {
      console.error("Error deleting project:", error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Error deleting project",
          variant: "error"
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  async refreshDashboard() {
    return refreshApex(this.wiredDashboardResult);
  }
}
