import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cardView", "listView", "cardButton", "listButton"]

  connect() {
    const savedMode = localStorage.getItem("urlf2_view_mode") || "card"
    if (savedMode === "list") {
      this.switchToList()
    } else {
      this.switchToCard()
    }
  }

  switchToCard() {
    this.cardViewTarget.classList.remove("hidden")
    this.listViewTarget.classList.add("hidden")
    this.updateButtonStates("card")
    localStorage.setItem("urlf2_view_mode", "card")
  }

  switchToList() {
    this.cardViewTarget.classList.add("hidden")
    this.listViewTarget.classList.remove("hidden")
    this.updateButtonStates("list")
    localStorage.setItem("urlf2_view_mode", "list")
  }

  updateButtonStates(activeMode) {
    if (activeMode === "card") {
      this.cardButtonTarget.classList.add("bg-blue-600", "text-white")
      this.cardButtonTarget.classList.remove("bg-gray-200", "text-gray-700")
      this.listButtonTarget.classList.add("bg-gray-200", "text-gray-700")
      this.listButtonTarget.classList.remove("bg-blue-600", "text-white")
    } else {
      this.listButtonTarget.classList.add("bg-blue-600", "text-white")
      this.listButtonTarget.classList.remove("bg-gray-200", "text-gray-700")
      this.cardButtonTarget.classList.add("bg-gray-200", "text-gray-700")
      this.cardButtonTarget.classList.remove("bg-blue-600", "text-white")
    }
  }
}
