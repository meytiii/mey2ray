(function () {
    'use strict';

    function escapeHtml(str) {
        if (typeof str !== 'string') return '';
        return str
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function showToast(message) {
        var toast = document.getElementById('toast');
        if (!toast) return;
        toast.textContent = message;
        toast.classList.add('show');
        setTimeout(function () {
            toast.classList.remove('show');
        }, 2500);
    }

    function copyToClipboard(text, successMsg) {
        if (!text) return;
        if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(text).then(function () {
                showToast(successMsg || 'Copied to clipboard');
            }).catch(function () {
                fallbackCopy(text, successMsg);
            });
        } else {
            fallbackCopy(text, successMsg);
        }
    }

    function fallbackCopy(text, successMsg) {
        var textArea = document.createElement('textarea');
        textArea.value = text;
        textArea.style.position = 'fixed';
        textArea.style.top = '-9999px';
        textArea.style.left = '-9999px';
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();
        try {
            var successful = document.execCommand('copy');
            if (successful) {
                showToast(successMsg || 'Copied to clipboard');
            } else {
                showToast('Failed to copy. Please select manually.');
            }
        } catch (err) {
            showToast('Failed to copy. Please select manually.');
        }
        document.body.removeChild(textArea);
    }

    function initDashboard() {
        var subUrlInput = document.getElementById('subUrlInput');
        var copySubBtn = document.getElementById('copySubBtn');
        var copyAllBtn = document.getElementById('copyAllBtn');
        var copyOfflineBtn = document.getElementById('copyOfflineBtn');
        var offlineCode = document.getElementById('offlineCode');
        var profileCountEl = document.getElementById('profileCount');
        var healthPill = document.getElementById('healthPill');
        var qrContainer = document.getElementById('qrCodeContainer');

        var detectedSubUrl = window.location.origin + '/sub';
        var allLinksText = '';
        var offlineBase64Text = '';

        fetch('/data.json')
            .then(function (res) {
                if (!res.ok) throw new Error('Data file not available');
                return res.json();
            })
            .then(function (data) {
                if (data.subscriptionUrl) {
                    detectedSubUrl = data.subscriptionUrl;
                }
                subUrlInput.value = detectedSubUrl;

                if (Array.isArray(data.links)) {
                    allLinksText = data.links.join('\n');
                    if (profileCountEl) {
                        profileCountEl.textContent = data.links.length + ' endpoints active';
                    }
                }

                if (data.offlineBase64) {
                    offlineBase64Text = data.offlineBase64;
                    if (offlineCode) {
                        offlineCode.textContent = data.offlineBase64;
                    }
                }

                renderQr(detectedSubUrl);
            })
            .catch(function () {
                subUrlInput.value = detectedSubUrl;
                renderQr(detectedSubUrl);
            });

        function renderQr(url) {
            if (window.QRCode && qrContainer) {
                qrContainer.innerHTML = '';
                try {
                    new window.QRCode(qrContainer, {
                        text: url,
                        width: 184,
                        height: 184
                    });
                } catch (e) {
                    qrContainer.textContent = 'QR Code unavailable';
                }
            }
        }

        if (copySubBtn) {
            copySubBtn.addEventListener('click', function () {
                copyToClipboard(subUrlInput.value, 'Subscription URL copied!');
            });
        }

        if (subUrlInput) {
            subUrlInput.addEventListener('click', function () {
                this.select();
                copyToClipboard(this.value, 'Subscription URL copied!');
            });
        }

        if (copyAllBtn) {
            copyAllBtn.addEventListener('click', function () {
                if (allLinksText) {
                    copyToClipboard(allLinksText, 'All VLESS links copied!');
                } else {
                    fetch('/sub')
                        .then(function (r) { return r.text(); })
                        .then(function (b64) {
                            try {
                                var decoded = atob(b64.trim());
                                copyToClipboard(decoded, 'All VLESS links copied!');
                            } catch (e) {
                                copyToClipboard(b64, 'Raw subscription copied!');
                            }
                        })
                        .catch(function () {
                            showToast('Unable to fetch links');
                        });
                }
            });
        }

        if (copyOfflineBtn) {
            copyOfflineBtn.addEventListener('click', function () {
                if (offlineBase64Text) {
                    copyToClipboard(offlineBase64Text, 'Offline Base64 block copied!');
                } else if (offlineCode && offlineCode.textContent) {
                    copyToClipboard(offlineCode.textContent.trim(), 'Offline Base64 block copied!');
                }
            });
        }

        fetch('/healthz')
            .then(function (res) {
                if (res.ok && healthPill) {
                    healthPill.innerHTML = '<span class="status-dot"></span><span>Local Proxy Engine Running</span>';
                }
            })
            .catch(function () {
                if (healthPill) {
                    healthPill.style.backgroundColor = 'rgba(245, 158, 11, 0.15)';
                    healthPill.style.color = '#F59E0B';
                    healthPill.innerHTML = '<span class="status-dot" style="background:#F59E0B"></span><span>Engine Listener Pending</span>';
                }
            });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initDashboard);
    } else {
        initDashboard();
    }
})();
