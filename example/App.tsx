import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import GameController from 'react-native-apple-game-controller';

function App(): React.JSX.Element {
  const controllers = GameController.getControllers();
  return (
    <View style={styles.container}>
      <Text style={styles.text}>Game Controller Example</Text>
      <Text style={styles.text}>Controllers: {controllers.length}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  text: { fontSize: 18, color: '#fff' },
});

export default App;
