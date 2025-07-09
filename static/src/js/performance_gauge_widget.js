odoo.define('hurimoney_concessionnaires.PerformanceGauge', function (require) {
    'use strict';

    const fieldRegistry = require('web.field_registry');
    const FieldFloat = require('web.basic_fields').FieldFloat;

    const PerformanceGauge = FieldFloat.extend({
        className: 'o_field_performance_gauge',
        tagName: 'div',

        _render: function () {
            const value = this.value || 0;
            const $gauge = $('<div>').addClass('performance-gauge');
            
            // Créer la jauge
            const $progress = $('<div>').addClass('progress').height('20px');
            const $bar = $('<div>')
                .addClass('progress-bar')
                .attr('role', 'progressbar')
                .attr('aria-valuenow', value)
                .attr('aria-valuemin', '0')
                .attr('aria-valuemax', '100')
                .css('width', value + '%');
            
            // Couleur selon la performance
            if (value >= 80) {
                $bar.addClass('bg-success');
            } else if (value >= 50) {
                $bar.addClass('bg-warning');
            } else {
                $bar.addClass('bg-danger');
            }
            
            // Texte
            $bar.text(value.toFixed(1) + '%');
            
            $progress.append($bar);
            $gauge.append($progress);
            
            this.$el.empty().append($gauge);
        },
    });

    fieldRegistry.add('performance_gauge', PerformanceGauge);

    return PerformanceGauge;
});