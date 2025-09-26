import { createElement } from "lwc";
import SelectDataSourceComponent from "c/selectDataSourceComponent";

describe("c-select-data-source-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders without errors", () => {
    // Arrange
    const element = createElement("c-select-data-source-component", {
      is: SelectDataSourceComponent
    });

    // Act
    document.body.appendChild(element);

    // Assert
    expect(element).toBeTruthy();
  });
});
