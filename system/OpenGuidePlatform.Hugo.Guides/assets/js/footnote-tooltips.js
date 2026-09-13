/**
 * Enhanced Footnote Citations with Bootstrap Tooltips
 * 
 * Adds interactive tooltips to footnote references that show citation details
 * without requiring users to scroll to the bottom of the page.
 * 
 * Features:
 * - Bootstrap 5 tooltip integration
 * - HTML content support for links and formatting
 * - Maintains click-through functionality
 * - Automatic initialization on page load
 */

(function() {
  'use strict';

  /**
   * Extract and format footnote reference content
   * @param {string} footnoteId - The footnote reference ID (e.g., "fn:1")
   * @returns {string|null} HTML formatted tooltip content
   */
  function getFootnoteContent(footnoteId) {
    // Find the corresponding footnote definition
    const footnoteElement = document.getElementById(footnoteId);
    if (!footnoteElement) {
      return null;
    }

    // Clone the content to avoid modifying the original
    const content = footnoteElement.cloneNode(true);
    
    // Remove the back-reference link (↩︎) from tooltip
    const backRef = content.querySelector('.footnote-backref');
    if (backRef) {
      backRef.remove();
    }

    // Get the text content and format it
    let html = content.innerHTML.trim();
    
    // Limit length for tooltip (optional)
    const maxLength = 300;
    if (html.length > maxLength) {
      html = html.substring(0, maxLength) + '...';
    }

    return html;
  }

  /**
   * Initialize tooltips for all footnote references
   */
  function initializeFootnoteTooltips() {
    // Find all footnote references in the content
    const footnoteRefs = document.querySelectorAll('a[href^="#fn:"]');
    
    footnoteRefs.forEach(ref => {
      // Extract footnote ID from href
      const href = ref.getAttribute('href');
      const footnoteId = href.substring(1); // Remove the '#'
      
      // Get the footnote content
      const tooltipContent = getFootnoteContent(footnoteId);
      
      if (tooltipContent) {
        // Add Bootstrap tooltip attributes
        ref.setAttribute('data-bs-toggle', 'tooltip');
        ref.setAttribute('data-bs-placement', 'top');
        ref.setAttribute('data-bs-html', 'true');
        ref.setAttribute('data-bs-title', tooltipContent);
        
        // Add custom class for styling
        ref.classList.add('footnote-tooltip');
        
        // Initialize the tooltip
        new bootstrap.Tooltip(ref, {
          html: true,
          trigger: 'hover focus',
          container: 'body',
          boundary: 'viewport',
          customClass: 'footnote-tooltip-content'
        });
      }
    });
  }

  /**
   * Initialize when DOM is ready
   */
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeFootnoteTooltips);
  } else {
    // DOM already loaded
    initializeFootnoteTooltips();
  }

})();
