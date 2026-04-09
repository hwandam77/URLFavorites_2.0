import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "menuItem"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  connect() {
    document.addEventListener("click", (e) => this.closeOnClickOutside(e))
  }

  disconnect() {
    document.removeEventListener("click", (e) => this.closeOnClickOutside(e))
  }
}
