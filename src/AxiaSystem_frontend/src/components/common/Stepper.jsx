import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import theme from '../styles/theme';

/**
 * Stepper Component
 *
 * @param {Object} props - Props for the stepper.
 * @param {Array} props.steps - Array of step labels.
 * @param {number} props.currentStep - Current active step (0-based index).
 * @param {Function} props.onStepPress - Callback when a step is pressed (optional).
 * @param {boolean} props.horizontal - Whether the stepper is horizontal or vertical.
 * @param {Object} props.style - Additional styles for the container.
 * @returns {JSX.Element}
 */
const Stepper = ({
  steps = [],
  currentStep = 0,
  onStepPress = null,
  horizontal = true,
  style = {},
}) => {
  return (
    <View
      style={[
        horizontal ? styles.horizontalContainer : styles.verticalContainer,
        style,
      ]}
    >
      {steps.map((label, index) => {
        const isActive = index === currentStep;
        const isCompleted = index < currentStep;

        return (
          <View
            key={index}
            style={[
              horizontal ? styles.horizontalStep : styles.verticalStep,
            ]}
          >
            <TouchableOpacity
              onPress={() => onStepPress && onStepPress(index)}
              disabled={!onStepPress}
              style={[
                styles.circle,
                isCompleted && styles.completedCircle,
                isActive && styles.activeCircle,
              ]}
            >
              <Text style={styles.stepText}>
                {isCompleted ? '✓' : index + 1}
              </Text>
            </TouchableOpacity>
            <Text
              style={[
                styles.label,
                isActive && styles.activeLabel,
                isCompleted && styles.completedLabel,
              ]}
            >
              {label}
            </Text>
            {index < steps.length - 1 && (
              <View
                style={[
                  horizontal ? styles.horizontalConnector : styles.verticalConnector,
                  isCompleted && styles.completedConnector,
                ]}
              />
            )}
          </View>
        );
      })}
    </View>
  );
};

const styles = StyleSheet.create({
  horizontalContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  verticalContainer: {
    flexDirection: 'column',
    alignItems: 'flex-start',
  },
  horizontalStep: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  verticalStep: {
    marginBottom: theme.spacing.lg,
  },
  circle: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: theme.colors.inactive,
    justifyContent: 'center',
    alignItems: 'center',
  },
  activeCircle: {
    backgroundColor: theme.colors.primary,
  },
  completedCircle: {
    backgroundColor: theme.colors.success,
  },
  stepText: {
    color: theme.colors.onPrimary,
    fontSize: theme.fontSizes.sm,
    fontWeight: 'bold',
  },
  label: {
    marginTop: 4,
    color: theme.colors.text,
    fontSize: theme.fontSizes.sm,
    textAlign: 'center',
  },
  activeLabel: {
    fontWeight: 'bold',
  },
  completedLabel: {
    color: theme.colors.success,
  },
  horizontalConnector: {
    flex: 1,
    height: 2,
    backgroundColor: theme.colors.inactive,
    marginHorizontal: theme.spacing.sm,
  },
  verticalConnector: {
    width: 2,
    height: 20,
    backgroundColor: theme.colors.inactive,
    alignSelf: 'center',
  },
  completedConnector: {
    backgroundColor: theme.colors.success,
  },
});

export default Stepper;