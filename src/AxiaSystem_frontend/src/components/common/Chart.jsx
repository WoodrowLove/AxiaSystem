import React from 'react';
import { View, StyleSheet } from 'react-native';
import { VictoryBar, VictoryChart, VictoryLine, VictoryPie, VictoryAxis, VictoryTheme } from 'victory-native';
import theme from '../styles/theme';

/**
 * Chart Component
 *
 * @param {Object} props - Props for the Chart component.
 * @param {string} props.type - Type of chart ('line', 'bar', 'pie').
 * @param {Array} props.data - Data to display in the chart.
 * @param {Object} props.style - Additional styles for the chart container.
 * @param {Object} props.chartProps - Additional props to pass to the Victory chart.
 * @returns {JSX.Element}
 */
const Chart = ({ type = 'line', data = [], style = {}, chartProps = {} }) => {
  const renderChart = () => {
    switch (type) {
      case 'line':
        return (
          <VictoryChart theme={VictoryTheme.material} {...chartProps}>
            <VictoryAxis
              style={{
                axis: { stroke: theme.colors.border },
                tickLabels: { fill: theme.colors.text },
              }}
            />
            <VictoryAxis
              dependentAxis
              style={{
                axis: { stroke: theme.colors.border },
                tickLabels: { fill: theme.colors.text },
              }}
            />
            <VictoryLine
              data={data}
              style={{
                data: { stroke: theme.colors.primary, strokeWidth: 2 },
              }}
            />
          </VictoryChart>
        );
      case 'bar':
        return (
          <VictoryChart theme={VictoryTheme.material} {...chartProps}>
            <VictoryAxis
              style={{
                axis: { stroke: theme.colors.border },
                tickLabels: { fill: theme.colors.text },
              }}
            />
            <VictoryAxis
              dependentAxis
              style={{
                axis: { stroke: theme.colors.border },
                tickLabels: { fill: theme.colors.text },
              }}
            />
            <VictoryBar
              data={data}
              style={{
                data: { fill: theme.colors.primary, width: 12 },
              }}
            />
          </VictoryChart>
        );
      case 'pie':
        return (
          <VictoryPie
            data={data}
            colorScale={[theme.colors.primary, theme.colors.secondary, theme.colors.tertiary]}
            labels={({ datum }) => `${datum.x}: ${datum.y}`}
            style={{
              labels: { fill: theme.colors.text, fontSize: 12 },
            }}
            {...chartProps}
          />
        );
      default:
        return null;
    }
  };

  return <View style={[styles.container, style]}>{renderChart()}</View>;
};

const styles = StyleSheet.create({
  container: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: theme.spacing.lg,
  },
});

export default Chart;