// Multi-level dropdown functionality for Bootstrap 5
document.addEventListener("DOMContentLoaded", function () {
  // Handle submenu clicks and hovers
  const submenuItems = document.querySelectorAll(".dropdown-submenu");

  submenuItems.forEach(function (submenu) {
    const submenuToggle = submenu.querySelector(".dropdown-toggle");
    const submenuDropdown = submenu.querySelector(".dropdown-menu");

    if (submenuToggle && submenuDropdown) {
      // Handle click events for mobile/touch devices
      submenuToggle.addEventListener("click", function (e) {
        e.preventDefault();
        e.stopPropagation();

        // Close other open submenus
        submenuItems.forEach(function (otherSubmenu) {
          if (otherSubmenu !== submenu) {
            const otherDropdown = otherSubmenu.querySelector(".dropdown-menu");
            if (otherDropdown) {
              otherDropdown.classList.remove("show");
            }
          }
        });

        // Toggle current submenu
        submenuDropdown.classList.toggle("show");
      });

      // Handle mouse enter/leave for desktop
      submenu.addEventListener("mouseenter", function () {
        if (window.innerWidth > 767) {
          submenuDropdown.classList.add("show");
        }
      });

      submenu.addEventListener("mouseleave", function () {
        if (window.innerWidth > 767) {
          submenuDropdown.classList.remove("show");
        }
      });
    }
  });

  // Close all submenus when main dropdown is closed
  const mainDropdown = document.querySelector(".dropdown");
  if (mainDropdown) {
    mainDropdown.addEventListener("hidden.bs.dropdown", function () {
      submenuItems.forEach(function (submenu) {
        const submenuDropdown = submenu.querySelector(".dropdown-menu");
        if (submenuDropdown) {
          submenuDropdown.classList.remove("show");
        }
      });
    });
  }

  // Close submenus when clicking outside
  document.addEventListener("click", function (e) {
    if (!e.target.closest(".dropdown-submenu")) {
      submenuItems.forEach(function (submenu) {
        const submenuDropdown = submenu.querySelector(".dropdown-menu");
        if (submenuDropdown) {
          submenuDropdown.classList.remove("show");
        }
      });
    }
  });
});
