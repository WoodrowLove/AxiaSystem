import React, { useState } from 'react';
import {
  View,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Platform,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import theme from '../styles/theme';
import shadows from '../styles/shadows';

/**
 * SearchBar Component
 *
 * @param {Object} props - Props for the SearchBar component.
 * @param {string} props.placeholder - Placeholder text for the search bar.
 * @param {Function} props.onSearch - Callback function when a search is triggered.
 * @param {Function} props.onChangeText - Callback for real-time input changes.
 * @param {string} props.value - Controlled value for the input field.
 * @param {Function} props.onClear - Callback function when the clear button is pressed.
 * @param {boolean} props.showSearchButton - Whether to show the search button.
 * @param {Object} props.style - Additional styles for the container.
 * @param {Object} props.inputStyle - Additional styles for the input field.
 * @returns {JSX.Element}
 */
const SearchBar = ({
  placeholder = 'Search...',
  onSearch = () => {},
  onChangeText = () => {},
  value = '',
  onClear = () => {},
  showSearchButton = true,
  style = {},
  inputStyle = {},
}) => {
  const [inputValue, setInputValue] = useState(value);

  const handleClear = () => {
    setInputValue('');
    onClear();
  };

  const handleChangeText = (text) => {
    setInputValue(text);
    onChangeText(text);
  };

  return (
    <View style={[styles.container, shadows.light, style]}>
      <MaterialIcons
        name="search"
        size={24}
        color={theme.colors.placeholder}
        style={styles.icon}
      />
      <TextInput
        style={[styles.input, inputStyle]}
        placeholder={placeholder}
        placeholderTextColor={theme.colors.placeholder}
        value={inputValue}
        onChangeText={handleChangeText}
        returnKeyType="search"
        onSubmitEditing={() => onSearch(inputValue)}
      />
      {inputValue.length > 0 && (
        <TouchableOpacity onPress={handleClear} style={styles.clearButton}>
          <MaterialIcons name="close" size={20} color={theme.colors.text} />
        </TouchableOpacity>
      )}
      {showSearchButton && (
        <TouchableOpacity onPress={() => onSearch(inputValue)} style={styles.searchButton}>
          <MaterialIcons name="arrow-forward" size={24} color={theme.colors.onPrimary} />
        </TouchableOpacity>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: theme.colors.inputBackground,
    borderRadius: theme.borderRadius.md,
    paddingHorizontal: theme.spacing.md,
    paddingVertical: Platform.OS === 'ios' ? 12 : 8,
  },
  icon: {
    marginRight: theme.spacing.sm,
  },
  input: {
    flex: 1,
    fontSize: theme.fontSizes.md,
    color: theme.colors.text,
    fontFamily: theme.typography.fontFamilyRegular,
  },
  clearButton: {
    marginHorizontal: theme.spacing.sm,
  },
  searchButton: {
    backgroundColor: theme.colors.primary,
    borderRadius: theme.borderRadius.sm,
    padding: 8,
    marginLeft: theme.spacing.sm,
  },
});

export default SearchBar;