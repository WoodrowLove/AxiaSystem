// MultiStepForm.js
import React, { useState } from 'react';
import { View, StyleSheet, TouchableOpacity, Text } from 'react-native';
import theme from '../styles/theme';
import Typography from './Typography';
import Button from './Button';

/**
 * Multi-Step Form Component
 *
 * @param {Object} props - Props for the Multi-Step Form component.
 * @param {Array} props.steps - Array of steps, where each step is an object with `component` and optional `title`.
 * @param {Function} props.onComplete - Callback when the form is completed.
 * @param {Function} [props.onStepChange] - Optional callback when the step changes.
 * @param {Object} props.style - Additional styles for the form container.
 * @returns {JSX.Element}
 */
const MultiStepForm = ({
  steps = [],
  onComplete,
  onStepChange = () => {},
  style = {},
}) => {
  const [currentStep, setCurrentStep] = useState(0);

  const isLastStep = currentStep === steps.length - 1;

  const handleNext = () => {
    if (!isLastStep) {
      setCurrentStep(currentStep + 1);
      onStepChange(currentStep + 1);
    } else {
      onComplete();
    }
  };

  const handlePrevious = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1);
      onStepChange(currentStep - 1);
    }
  };

  return (
    <View style={[styles.container, style]}>
      {steps[currentStep]?.title && (
        <Typography
          variant="heading"
          style={styles.title}
          color={theme.colors.primary}
        >
          {steps[currentStep].title}
        </Typography>
      )}

      <View style={styles.content}>
        {steps[currentStep]?.component || null}
      </View>

      <View style={styles.navigation}>
        {currentStep > 0 && (
          <Button
            title="Previous"
            onPress={handlePrevious}
            variant="secondary"
            style={styles.button}
          />
        )}
        <Button
          title={isLastStep ? 'Submit' : 'Next'}
          onPress={handleNext}
          style={styles.button}
        />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: theme.spacing.md,
    backgroundColor: theme.colors.background,
  },
  title: {
    marginBottom: theme.spacing.md,
    textAlign: 'center',
  },
  content: {
    flex: 1,
    marginBottom: theme.spacing.lg,
  },
  navigation: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  button: {
    flex: 1,
    marginHorizontal: theme.spacing.sm,
  },
});

export default MultiStepForm;