'use strict';

/**
 * Helpers de UI compartidos: mensajes de error/exito amigables, estados de
 * carga y formateo. Sin dependencias externas. Apoya la DISPONIBILIDAD
 * percibida: nunca dejar la pantalla en blanco ante un error.
 */
(function (global) {
  function escapeHtml(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function setMessage(el, text, type) {
    if (!el) return;
    el.textContent = text || '';
    el.className = 'message' + (type ? ' message--' + type : '');
    el.hidden = !text;
  }

  function showError(el, err) {
    const msg = (err && err.message) || 'Ocurrio un error inesperado.';
    setMessage(el, msg, 'error');
  }

  function showInfo(el, text) {
    setMessage(el, text, 'info');
  }

  function showSuccess(el, text) {
    setMessage(el, text, 'success');
  }

  function clearMessage(el) {
    setMessage(el, '', null);
  }

  function setLoading(button, loading, loadingText) {
    if (!button) return;
    if (loading) {
      button.dataset.label = button.textContent;
      button.textContent = loadingText || 'Cargando…';
      button.disabled = true;
    } else {
      if (button.dataset.label) button.textContent = button.dataset.label;
      button.disabled = false;
    }
  }

  function money(value) {
    const n = Number(value);
    return Number.isFinite(n) ? n.toFixed(2) : String(value);
  }

  function fecha(value) {
    if (!value) return '';
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? String(value) : d.toISOString().slice(0, 10);
  }

  function qs(name) {
    return new URLSearchParams(global.location.search).get(name);
  }

  global.UI = {
    escapeHtml,
    setMessage,
    showError,
    showInfo,
    showSuccess,
    clearMessage,
    setLoading,
    money,
    fecha,
    qs,
  };
})(window);
