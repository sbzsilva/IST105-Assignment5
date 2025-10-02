import random
import math
from django.shortcuts import render
from .forms import PuzzleForm

def home(request):
    result = None
    if request.method == 'POST':
        form = PuzzleForm(request.POST)
        if form.is_valid():
            number = form.cleaned_data['number']
            text = form.cleaned_data['text']
            
            # Number Puzzle
            if number % 2 == 0:
                number_result = f"Even number. Square root: {math.sqrt(number)}"
            else:
                number_result = f"Odd number. Cube: {number ** 3}"
            
            # Text Puzzle
            binary_text = ' '.join(format(ord(c), '08b') for c in text)
            vowel_count = sum(1 for c in text.lower() if c in 'aeiou')
            
            # Treasure Hunt
            target = random.randint(1, 100)
            guesses = 0
            guess_results = []
            won = False
            
            for i in range(5):
                guess = random.randint(1, 100)
                guesses += 1
                if guess == target:
                    won = True
                    guess_results.append(f"Guess #{guesses}: {guess} - Correct! You found the treasure!")
                    break
                elif guess < target:
                    guess_results.append(f"Guess #{guesses}: {guess} - Too low!")
                else:
                    guess_results.append(f"Guess #{guesses}: {guess} - Too high!")
            
            if not won:
                guess_results.append(f"Failed to find the treasure in 5 guesses. The target was {target}.")
            
            result = {
                'number_result': number_result,
                'binary_text': binary_text,
                'vowel_count': vowel_count,
                'guess_results': guess_results,
                'won': won
            }
    else:
        form = PuzzleForm()
    
    return render(request, 'puzzle/home.html', {'form': form, 'result': result})