import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const savedTheme = localStorage.getItem("theme")
    if (savedTheme === "dark" || savedTheme === "sepia") {
      document.documentElement.classList.add(savedTheme)
    }
  }

  toggle() {
    const html = document.documentElement
    if (html.classList.contains("dark")) {
      html.classList.remove("dark")
      html.classList.add("sepia")
      localStorage.setItem("theme", "sepia")
    } else if (html.classList.contains("sepia")) {
      html.classList.remove("sepia")
      localStorage.removeItem("theme")
    } else {
      html.classList.add("dark")
      localStorage.setItem("theme", "dark")
    }
  }
}
