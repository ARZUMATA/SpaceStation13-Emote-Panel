// Store character configs
window.characterConfigs = {};
window.mainConfig = {}; // Will hold the main config

// Handle messages from AHK
window.addEventListener('DOMContentLoaded', function () {
    window.chrome.webview.addEventListener('message', function (event) {
        try {
            // Try parsing as JSON first
            let msg;
            if (typeof event.data === 'string') {
                msg = JSON.parse(event.data);
            } else {
                msg = event.data;
            }

            console.log("Received message:", msg);

            if (msg.type === "config") {
                // Store main config
                window.mainConfig = msg.data;
                console.log("Main config loaded:", window.mainConfig);
            }
            else if (msg.type === "charConfigs") {
                // Process character configs
                msg.data.forEach(charConfig => {
                    window.characterConfigs[charConfig.name] = charConfig;
                });
                console.log("Character configs loaded:", window.characterConfigs);
                // Update sidebar with character names
                updateSidebarWithCharacters();
                // Create tab panes for each character
                createCharacterTabPanes();
            }
        } catch (e) {
            console.error("Error processing message:", e, event.data);
        }
    });
});

// Add custom tooltip functionality
document.addEventListener('DOMContentLoaded', function () {
    // Add mouseover event for buttons with data-command
    document.addEventListener('mouseover', function (e) {
        if (e.target.tagName === 'BUTTON' && e.target.hasAttribute('data-command')) {
            const command = e.target.getAttribute('data-command');
            if (command) {
                // Show tooltip after delay
                e.target.tooltipTimer = setTimeout(() => {
                    showTooltip(e.target, command);
                }, 500); // 500ms delay
            }
        }
    });

    // Add mouseout event to hide tooltip
    document.addEventListener('mouseout', function (e) {
        if (e.target.tagName === 'BUTTON' && e.target.hasAttribute('data-command')) {
            // Clear timeout if mouse leaves before tooltip shows
            if (e.target.tooltipTimer) {
                clearTimeout(e.target.tooltipTimer);
            }
            // Hide tooltip
            hideTooltip();
        }
    });
});

function showTooltip(element, text) {
    // Remove any existing tooltips
    hideTooltip();

    // Create tooltip element
    const tooltip = document.createElement('div');
    tooltip.id = 'custom-tooltip';
    tooltip.textContent = text;
    tooltip.style.position = 'fixed';
    tooltip.style.backgroundColor = '#333';
    tooltip.style.color = '#fff';
    tooltip.style.padding = '4px 8px';
    tooltip.style.borderRadius = '4px';
    tooltip.style.fontSize = '12px';
    tooltip.style.zIndex = '10000';
    tooltip.style.pointerEvents = 'none';
    tooltip.style.boxShadow = '0 2px 4px rgba(0,0,0,0.2)';
    tooltip.style.maxWidth = '200px';
    tooltip.style.wordWrap = 'break-word';
    tooltip.style.textAlign = 'center';

    // Position tooltip near the button
    const rect = element.getBoundingClientRect();
    tooltip.style.left = rect.left + 'px';
    tooltip.style.top = (rect.top - 25) + 'px';

    document.body.appendChild(tooltip);

    // Adjust position if tooltip goes off screen
    const tooltipRect = tooltip.getBoundingClientRect();
    if (tooltipRect.right > window.innerWidth) {
        tooltip.style.left = (window.innerWidth - tooltipRect.width - 10) + 'px';
    }
    if (tooltipRect.left < 0) {
        tooltip.style.left = '10px';
    }
}

function hideTooltip() {
    const tooltip = document.getElementById('custom-tooltip');
    if (tooltip) {
        tooltip.remove();
    }
}

function updateSidebarWithCharacters() {
    const sidebar = document.querySelector('ul[role="tablist"]');
    if (!sidebar) return;

    // Remove existing character tabs (except Home)
    const existingCharTabs = document.querySelectorAll('.character-tab');
    existingCharTabs.forEach(tab => tab.remove());

    // Add character tabs
    let index = 1;
    for (const charName in window.characterConfigs) {
        const tabId = `v-pills-character-${index}`;
        const navItem = document.createElement('li');
        navItem.className = 'nav-item character-tab';
        navItem.innerHTML = `
        <a class="nav-link link-body-emphasis" data-bs-toggle="pill" role="tab" 
            href="#${tabId}" id="${tabId}-tab" aria-controls="${tabId}" aria-selected="false">
            <svg class="bi pe-none " width="16" height="16"><use xlink:href="#people-circle"/></svg>
            <span class="nav-text">${charName}</span>
        </a>
        `;
        sidebar.appendChild(navItem);
        index++;
    }
}

function createCharacterTabPanes() {
    const tabContent = document.getElementById('v-pills-tabContent');
    if (!tabContent) return;

    // Remove existing character panes (except home and buttons)
    const existingPanes = document.querySelectorAll('.character-pane');
    existingPanes.forEach(pane => pane.remove());

    // Get button dimensions from config or use defaults
    const buttonWidth = window.mainConfig.buttonWidth || 90;
    const buttonHeight = window.mainConfig.buttonHeight || 25;
    const buttonSpacing = window.mainConfig.buttonSpacing || 5;

    // Create tab panes for each character
    let index = 1;
    for (const charName in window.characterConfigs) {
        const charConfig = window.characterConfigs[charName];
        const tabId = `v-pills-character-${index}`;

        const tabPane = document.createElement('div');
        tabPane.className = 'tab-pane fade character-pane';
        tabPane.id = tabId;
        tabPane.setAttribute('role', 'tabpanel');
        tabPane.setAttribute('aria-labelledby', `${tabId}-tab`);

        // Generate buttons based on character config
        let buttonsHTML = `<div class="tab-container">`;

        // Transpose the buttons matrix to go column by column
        const maxRows = Math.max(...charConfig.buttons.map(row => row.length), 0);
        const maxCols = charConfig.buttons.length;

        // Create buttons for each column (top to bottom)
        for (let colIndex = 0; colIndex < maxRows; colIndex++) {
            buttonsHTML += `<div class="button-row" style="margin-bottom: ${buttonSpacing}px;">`;
            for (let rowIndex = 0; rowIndex < maxCols; rowIndex++) {
                // Check if this column exists in this row
                if (colIndex < charConfig.buttons[rowIndex].length) {
                    const button = charConfig.buttons[rowIndex][colIndex];
                    const btnStyle = button.style || 'btn btn-primary';
                    const btnId = `btn-${index}-${rowIndex}-${colIndex}`;
                    const command = button.command || '';
                    const emote = button.emote ? 'true' : 'false';
                    
                    // Check if button is audible
                    const audibleIcon = button.audible ? '<img class="bi pe-none white-icon" width="16" height="16" src="svg/sound.svg" style="margin-left: 5px; vertical-align: middle;">' : '';

                    buttonsHTML += `
                    <button type="button" id="${btnId}" onclick="sendEmoteCommand(this)" 
                            class="${btnStyle}" 
                            style="width: ${buttonWidth}px; height: ${buttonHeight}px; margin: ${buttonSpacing / 2}px; padding: 0 5px; box-sizing: border-box; display: inline-flex; align-items: center; justify-content: center; white-space: nowrap;"
                            data-command="${command}"
                            data-emote="${emote}">
                        <span style="flex: 1; text-align: center;">${button.text}</span>
                        ${audibleIcon}
                    </button>
                    `;
                } else {
                    // Add invisible spacer button for alignment
                    buttonsHTML += `
                    <button type="button" 
                            class="btn btn-primary invisible-btn" 
                            style="width: ${buttonWidth}px; height: ${buttonHeight}px; margin: ${buttonSpacing / 2}px; padding: 0; box-sizing: border-box; visibility: hidden; display: inline-block;">
                    </button>
                    `;
                }
            }
            buttonsHTML += '</div>';
        }

        buttonsHTML += '</div>';
        tabPane.innerHTML = buttonsHTML;
        tabContent.appendChild(tabPane);
        index++;
    }
}

// Variables for drag functionality
let isDragging = false;
let dragOffsetX = 0;
let dragOffsetY = 0;

function togglePanel() {
    const titleBar = document.querySelector('.ahk-titleBar');
    const sidebar = document.querySelector('.d-flex.flex-column');
    const divider = document.querySelector('.b-example-vr');
    const pageContent = document.getElementById('page-content');
    const hideText = document.querySelector('.fs-4.nav-text');
    const navLink = document.querySelector('.fs-4.nav-text').closest('a');

    if (hideText.textContent === 'Hide') {
        // Hide everything except the Show button
        titleBar.style.display = 'none';
        sidebar.style.display = 'none';
        divider.style.display = 'none';
        pageContent.style.display = 'none';
        hideText.textContent = 'Show';
        navLink.style.position = 'fixed';
        navLink.style.top = '0';
        navLink.style.left = '0';
        navLink.style.width = '100%';
        navLink.style.height = '100%';
        navLink.style.margin = '0';
        navLink.style.padding = '0';
        navLink.style.display = 'flex';
        navLink.style.alignItems = 'center';
        navLink.style.justifyContent = 'center';
        navLink.style.zIndex = '9999';
        navLink.style.backgroundColor = '#0d6efd';
        navLink.style.color = 'white';
        navLink.style.textDecoration = 'none';
        navLink.style.userSelect = 'none';
        navLink.style.cursor = 'move';
        navLink.style["-webkit-app-region"] = 'drag';  // Make entire element draggable

        // Make the text draggable too
        hideText.style["-webkit-app-region"] = 'drag';
        hideText.style.cursor = 'pointer';

        // Send message to AHK via Host Object (same method as buttons)
        try {
            if (typeof ahk !== 'undefined' && typeof ahk.PanelToggle !== 'undefined') {
                console.log("Sending hide command to AHK");
                ahk.PanelToggle.Func('hide')
                    .then(result => console.log("AHK hide response:", result))
                    .catch(error => console.error("AHK hide error:", error));
            } else {
                console.log("AHK PanelToggle not available");
            }
        } catch (e) {
            console.error("Error sending hide command to AHK:", e);
        }
    } else {
        // Show everything
        titleBar.style.display = 'flex';
        sidebar.style.display = 'flex';
        divider.style.display = 'block';
        pageContent.style.display = 'block';
        hideText.textContent = 'Hide';
        navLink.style.position = 'static';
        navLink.style.width = 'auto';
        navLink.style.height = 'auto';
        navLink.style.margin = '0 auto';
        navLink.style.padding = '';
        navLink.style.display = 'flex';
        navLink.style.alignItems = 'center';
        navLink.style.justifyContent = 'center';
        navLink.style.zIndex = 'auto';
        navLink.style.backgroundColor = 'transparent';
        navLink.style.color = '';
        navLink.style.cursor = 'default';
        navLink.style["-webkit-app-region"] = 'no-drag';

        // Reset text element styles
        hideText.style["-webkit-app-region"] = '';
        hideText.style.cursor = '';

        // Send message to AHK via Host Object (same method as buttons)
        try {
            if (typeof ahk !== 'undefined' && typeof ahk.PanelToggle !== 'undefined') {
                console.log("Sending show command to AHK");
                ahk.PanelToggle.Func('show')
                    .then(result => console.log("AHK show response:", result))
                    .catch(error => console.error("AHK show error:", error));
            } else {
                console.log("AHK PanelToggle not available");
            }
        } catch (e) {
            console.error("Error sending show command to AHK:", e);
        }
    }
}

function collapsePanel(element) {
    var navText = document.getElementsByClassName("nav-text");
    for (i = 0; i < navText.length; i++) {
        if (navText[i].style.display === "none") {
            navText[i].style.display = "inline-block";
        }
        else {
            navText[i].style.display = "none";
        }
    }

    // Change the glyph icon and text for the collapse button only
    var glyph = element.querySelector('.glyphicon');
    var textSpan = element.querySelector('.button-text');
    if (glyph) {
        if (glyph.classList.contains('glyphicon-chevron-left')) {
            glyph.classList.remove('glyphicon-chevron-left');
            glyph.classList.add('glyphicon-chevron-right');
            if (textSpan) textSpan.textContent = '';
        } else {
            glyph.classList.remove('glyphicon-chevron-right');
            glyph.classList.add('glyphicon-chevron-left');
            if (textSpan) textSpan.textContent = 'Collapse';
        }
    }
}

window.chrome.webview.addEventListener('message', ahkWebMessage);
function ahkWebMessage(Msg) {
    console.log(Msg.data);
}

function sendEmoteCommand(ele) {
    // Get text from element
    var text = "";
    if (ele.Id != null && ele.Id !== "") {
        text = ele.Id;
    } else if (ele.Name != null && ele.Name !== "") {
        text = ele.Name;
    } else if (ele.innerText != null && ele.innerText !== "") {
        text = ele.innerText;
    } else {
        text = ele.outerHTML;
    }

    // Get command from data attribute or default to text
    var command = text; // Default to text
    if (ele.hasAttribute('data-command')) {
        command = ele.getAttribute('data-command');
    }

    // Check if this is an emote (from data-emote attribute or class)
    var emote = false;
    if (ele.hasAttribute('data-emote')) {
        emote = ele.getAttribute('data-emote') === 'true';
    } else if (ele.classList.contains('emote')) {
        emote = true;
    }

    // Create JSON object with all three values
    var buttonData = {
        text: text,
        command: command,
        emote: emote
    };

    // Send as JSON string
    ahk.ButtonClick.Func(JSON.stringify(buttonData));
}

// Let's you copy button styles from previews for use in JSON configuration
// Double-click any button to copy its class names to clipboard
function buttonPreviewClick(element) {
    // Get the class attribute from the clicked button
    const classList = element.className;
    
    // Copy to clipboard
    navigator.clipboard.writeText(classList).then(function() {
        // Show visual feedback
        const originalText = element.textContent;
        element.textContent = "Copied!";
        element.style.opacity = "0.7";
        
        // Reset after 1 second
        setTimeout(function() {
            element.textContent = originalText;
            element.style.opacity = "1";
        }, 1000);
        
        // Show notification (optional)
        console.log("Copied to clipboard: " + classList);
    }).catch(function(error) {
        console.error("Copy failed: ", error);
        alert("Failed to copy class name to clipboard");
    });
}

// Disable right-click context menu
document.addEventListener('contextmenu', function(e) {
    e.preventDefault();
    return false;
});