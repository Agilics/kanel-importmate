import { LightningElement, track } from "lwc";

export default class SimpleCounter extends LightningElement {
  @track count = 0;

  get displayCount() {
    return `Count: ${this.count}`;
  }

  get isEven() {
    return this.count % 2 === 0;
  }

  increment() {
    this.count++;
  }

  decrement() {
    this.count--;
  }

  reset() {
    this.count = 0;
  }
}
