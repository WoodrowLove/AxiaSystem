// Input.js
import React, { useState } from 'react';
import {
  TextInput,
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import shadows from '../styles/shadows';
import theme from '../styles/theme';
import Typography from './Typography';

const Input = ({
  label, // Input label
  placeholder, // Placeholder text
  value, // Current value of the input
  onChangeText, // Function to update the value
  secureTextEntry = false, // Toggle for password inputs
  keyboardType = 'default', // Keyboard type (e.g., 'email-address', 'numeric')
  error = null, // Error message for validation
  style, // Additional styles for the input container
  inputStyle, // Additional styles for the TextInput
  labelStyle, // Additional styles for the label
  leftIcon, // Optional icon on the left
  rightIcon, // Optional icon on the right
  onLeftIconPress, // Function for the left icon press
  onRightIconPress, // Function for the right icon press
  loading = false, // Show loading spinner
  borderStyle = {}, // Custom border styles
}) => {
  const [isFocused, setIsFocused] = useState(false);

  const handleFocus = () => setIsFocused(true);
  const handleBlur = () => setIsFocused(false);

  return (
    <View style={[styles.container, style]}>
      {label && (
        <Typography
          variant="subheading"
          color={theme.colors.text}
          style={[styles.label, labelStyle]}
        >
          {label}
        </Typography>
      )}
      <View
        style={[
          styles.inputWrapper,
          shadows.light,
          isFocused && styles.focused,
          error && styles.error,
          borderStyle,
        ]}
      >
        {leftIcon && (
          <TouchableOpacity
            onPress={onLeftIconPress}
            style={styles.leftIconContainer}
          >
            {leftIcon}
          </TouchableOpacity>
        )}
        <TextInput
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder}
          placeholderTextColor={theme.colors.placeholder}
          secureTextEntry={secureTextEntry}
          keyboardType={keyboardType}
          style={[styles.input, inputStyle]}
          onFocus={handleFocus}
          onBlur={handleBlur}
          accessibilityLabel={label || placeholder}
          accessibilityHint={placeholder || ''}
        />
        {loading && (
          <ActivityIndicator
            size="small"
            color={theme.colors.primary}
            style={styles.loadingSpinner}
          />
        )}
        {rightIcon && (
          <TouchableOpacity
            onPress={onRightIconPress}
            style={styles.rightIconContainer}
          >
            {rightIcon}
          </TouchableOpacity>
        )}
      </View>
      {error && (
        <Typography
          variant="caption"
          color={theme.colors.error}
          style={styles.errorText}
        >
          {error}
        </Typography>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginBottom: theme.sizes.spacing,
  },
  label: {
    marginBottom: 4,
  },
  inputWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: theme.colors.inputBackground,
    borderRadius: theme.sizes.borderRadius,
    paddingHorizontal: theme.sizes.inputPaddingHorizontal,
    paddingVertical: theme.sizes.inputPaddingVertical,
    borderWidth: 1,
    borderColor: theme.colors.border,
  },
  input: {
    flex: 1,
    color: theme.colors.text,
    fontSize: theme.sizes.inputFontSize,
    fontFamily: theme.typography.fontFamilyRegular,
  },
  leftIconContainer: {
    marginRight: 8,
  },
  rightIconContainer: {
    marginLeft: 8,
  },
  loadingSpinner: {
    marginLeft: 8,
  },
  focused: {
    borderColor: theme.colors.primary,
    ...shadows.medium,
  },
  error: {
    borderColor: theme.colors.error,
  },
  errorText: {
    marginTop: 4,
  },
});

export default Input;