import { LightningElement, api, track } from "lwc";

export default class HelloWorld extends LightningElement {
  @api name = "World";
  @api greeting = "Hello";
  @track clickCount = 0;
  @track showDetails = false;

  get fullGreeting() {
    return `${this.greeting}, ${this.name}!`;
  }

  get clickCountText() {
    return `Clicked ${this.clickCount} time${this.clickCount !== 1 ? "s" : ""}`;
  }

  get isClickCountHigh() {
    return this.clickCount > 5;
  }

  handleClick() {
    this.clickCount++;
    this.dispatchEvent(
      new CustomEvent("greetingclick", {
        detail: {
          name: this.name,
          clickCount: this.clickCount
        }
      })
    );
  }

  toggleDetails() {
    this.showDetails = !this.showDetails;
  }

  resetCount() {
    this.clickCount = 0;
  }
}
