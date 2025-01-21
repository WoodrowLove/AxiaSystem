import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  FlatList,
  Modal,
  StyleSheet,
  TextInput,
} from 'react-native';
import theme from '../styles/theme';
import shadows from '../styles/shadows';

/**
 * Dropdown/Picker Component
 *
 * @param {Object} props - Props for the Dropdown/Picker component.
 * @param {Array} props.options - Array of options [{ label: string, value: any }].
 * @param {Function} props.onSelect - Callback for selected value(s).
 * @param {string} props.placeholder - Placeholder text for the dropdown.
 * @param {boolean} props.multiple - Whether the dropdown allows multiple selections.
 * @param {Object} props.style - Additional styles for the dropdown container.
 * @param {boolean} props.searchable - Whether the dropdown includes a search bar.
 * @returns {JSX.Element}
 */
const Dropdown = ({
  options = [],
  onSelect,
  placeholder = 'Select an option',
  multiple = false,
  style = {},
  searchable = false,
}) => {
  const [visible, setVisible] = useState(false);
  const [selectedValues, setSelectedValues] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');

  const toggleOption = (value) => {
    if (multiple) {
      if (selectedValues.includes(value)) {
        setSelectedValues(selectedValues.filter((v) => v !== value));
      } else {
        setSelectedValues([...selectedValues, value]);
      }
    } else {
      setSelectedValues([value]);
      setVisible(false);
    }
    onSelect(multiple ? [...selectedValues, value] : value);
  };

  const filteredOptions = searchQuery
    ? options.filter((option) =>
        option.label.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : options;

  return (
    <>
      <TouchableOpacity
        style={[styles.container, shadows.light, style]}
        onPress={() => setVisible(true)}
      >
        <Text style={styles.placeholder}>
          {selectedValues.length
            ? selectedValues.map((v) => options.find((o) => o.value === v)?.label).join(', ')
            : placeholder}
        </Text>
      </TouchableOpacity>
      <Modal visible={visible} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, shadows.medium]}>
            {searchable && (
              <TextInput
                style={styles.searchBar}
                placeholder="Search..."
                value={searchQuery}
                onChangeText={setSearchQuery}
              />
            )}
            <FlatList
              data={filteredOptions}
              keyExtractor={(item) => item.value.toString()}
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={[
                    styles.option,
                    selectedValues.includes(item.value) && styles.selectedOption,
                  ]}
                  onPress={() => toggleOption(item.value)}
                >
                  <Text
                    style={[
                      styles.optionText,
                      selectedValues.includes(item.value) && styles.selectedOptionText,
                    ]}
                  >
                    {item.label}
                  </Text>
                </TouchableOpacity>
              )}
            />
            <TouchableOpacity
              style={styles.closeButton}
              onPress={() => setVisible(false)}
            >
              <Text style={styles.closeButtonText}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </>
  );
};

const styles = StyleSheet.create({
  container: {
    padding: theme.spacing.md,
    borderWidth: 1,
    borderColor: theme.colors.border,
    borderRadius: theme.borderRadius.md,
    backgroundColor: theme.colors.inputBackground,
  },
  placeholder: {
    color: theme.colors.placeholder,
    fontSize: theme.fontSizes.md,
  },
  modalOverlay: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalContent: {
    width: '80%',
    maxHeight: '60%',
    padding: theme.spacing.md,
    backgroundColor: theme.colors.background,
    borderRadius: theme.borderRadius.md,
  },
  searchBar: {
    marginBottom: theme.spacing.sm,
    padding: theme.spacing.sm,
    borderWidth: 1,
    borderColor: theme.colors.border,
    borderRadius: theme.borderRadius.sm,
  },
  option: {
    padding: theme.spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.border,
  },
  optionText: {
    color: theme.colors.text,
    fontSize: theme.fontSizes.md,
  },
  selectedOption: {
    backgroundColor: theme.colors.primaryLight,
  },
  selectedOptionText: {
    color: theme.colors.primary,
    fontWeight: 'bold',
  },
  closeButton: {
    marginTop: theme.spacing.md,
    alignSelf: 'center',
    padding: theme.spacing.sm,
    backgroundColor: theme.colors.primary,
    borderRadius: theme.borderRadius.sm,
  },
  closeButtonText: {
    color: theme.colors.white,
    fontSize: theme.fontSizes.md,
    fontWeight: 'bold',
  },
});

export default Dropdown;