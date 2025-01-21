// ChatInterface.js
import React, { useState } from 'react';
import {
  View,
  FlatList,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Text,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import theme from '../styles/theme';

/**
 * ChatInterface Component
 *
 * @param {Object} props - Props for the chat interface.
 * @param {Array} props.messages - Array of messages {id, text, sender, timestamp}.
 * @param {Function} props.onSend - Callback to send a message.
 * @param {string} props.currentUser - Identifier for the current user.
 * @param {Object} props.style - Additional styles for the chat interface.
 * @returns {JSX.Element}
 */
const ChatInterface = ({ messages = [], onSend, currentUser, style = {} }) => {
  const [text, setText] = useState('');

  const handleSend = () => {
    if (text.trim() && onSend) {
      onSend(text);
      setText('');
    }
  };

  const renderMessage = ({ item }) => {
    const isCurrentUser = item.sender === currentUser;
    return (
      <View
        style={[
          styles.messageContainer,
          isCurrentUser ? styles.currentUserMessage : styles.otherUserMessage,
        ]}
      >
        <Text style={styles.messageText}>{item.text}</Text>
        <Text style={styles.timestamp}>{new Date(item.timestamp).toLocaleTimeString()}</Text>
      </View>
    );
  };

  return (
    <KeyboardAvoidingView
      style={[styles.container, style]}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <FlatList
        data={messages}
        renderItem={renderMessage}
        keyExtractor={(item) => item.id.toString()}
        contentContainerStyle={styles.messageList}
        inverted
      />
      <View style={styles.inputContainer}>
        <TextInput
          style={styles.input}
          placeholder="Type a message..."
          value={text}
          onChangeText={setText}
          placeholderTextColor={theme.colors.placeholder}
        />
        <TouchableOpacity style={styles.sendButton} onPress={handleSend}>
          <Text style={styles.sendButtonText}>Send</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  messageList: {
    paddingHorizontal: theme.spacing.md,
    paddingVertical: theme.spacing.sm,
  },
  messageContainer: {
    marginVertical: theme.spacing.xs,
    padding: theme.spacing.sm,
    borderRadius: theme.borderRadius.md,
    maxWidth: '80%',
    alignSelf: 'flex-start',
  },
  currentUserMessage: {
    alignSelf: 'flex-end',
    backgroundColor: theme.colors.primary,
  },
  otherUserMessage: {
    backgroundColor: theme.colors.secondary,
  },
  messageText: {
    color: theme.colors.onPrimary,
    fontSize: theme.fontSizes.md,
  },
  timestamp: {
    color: theme.colors.placeholder,
    fontSize: theme.fontSizes.sm,
    alignSelf: 'flex-end',
    marginTop: 4,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    borderTopWidth: 1,
    borderColor: theme.colors.border,
    padding: theme.spacing.sm,
    backgroundColor: theme.colors.surface,
  },
  input: {
    flex: 1,
    borderRadius: theme.borderRadius.sm,
    borderWidth: 1,
    borderColor: theme.colors.border,
    paddingHorizontal: theme.spacing.sm,
    paddingVertical: Platform.OS === 'ios' ? theme.spacing.xs : 0,
    marginRight: theme.spacing.sm,
    color: theme.colors.text,
    backgroundColor: theme.colors.inputBackground,
  },
  sendButton: {
    backgroundColor: theme.colors.primary,
    borderRadius: theme.borderRadius.md,
    paddingHorizontal: theme.spacing.md,
    paddingVertical: theme.spacing.xs,
  },
  sendButtonText: {
    color: theme.colors.onPrimary,
    fontSize: theme.fontSizes.md,
    fontWeight: 'bold',
  },
});

export default ChatInterface;