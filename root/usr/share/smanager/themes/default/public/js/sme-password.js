// public/js/sme-password.js
// Requires: jQuery + local zxcvbn.js - needs to be loaded before this
// Adds:
// - Eye icon inside the password control (overlay at far right)
// - Dice icon (random password generator) between the control and strength bar
// - Strength bar + English hint text (bar updates via classes; CSP-friendly)

$(document).ready(function () {

  // -----------------------------
  // 1) Password visibility toggle
  //    - Wrap input in .input-container (positioned)
  //    - Add eye icon INSIDE the control (overlay)
  // -----------------------------
  $('.sme-password').each(function () {
    var $pw = $(this);

    // Wrap once
    if (!$pw.parent().hasClass('input-container')) {
      $pw.wrap('<div class="input-container"></div>');
    }

    var $container = $pw.parent('.input-container');

    // Add toggle icon once
    if (!$container.find('.toggle-password').length) {
      var $toggle = $(
        '<img src="images/visible.png" alt="Show Password" class="toggle-password" />'
      );
      $container.append($toggle);
    }
  });

  // Delegate click for dynamic content
  $(document).on('click', '.toggle-password', function () {
    var $container = $(this).closest('.input-container');
    var $input = $container.find('.sme-password').first();
    if (!$input.length) return;

    var inputType = $input.attr('type') === 'password' ? 'text' : 'password';
    $input.attr('type', inputType);

    var iconSrc = inputType === 'password'
      ? 'images/visible.png'
      : 'images/visible-slash.png';

    $(this).attr('src', iconSrc);
  });


  // ---------------------------------------
  // 2) Form submit: visually disable submits
  // ---------------------------------------
  $('form').on('submit', function (e) {
	const submitter = e.originalEvent && e.originalEvent.submitter;
	if (submitter && submitter.classList.contains('no-disable')) {
		return true; // don't change button, don't add busy
	}
	
    $(this).find('button[type="submit"]').each(function () {
      $(this).text('Please wait...')
        .addClass('visually-disabled')
        .css({
          'pointer-events': 'none',
          'opacity': '0.6',
          'cursor': 'not-allowed'
        });
    });

    $(this).find('input[type="submit"]').each(function () {
      $(this).val('Please wait...')
        .addClass('visually-disabled')
        .css({
          'pointer-events': 'none',
          'opacity': '0.6',
          'cursor': 'not-allowed'
        });
    });

    $('body').addClass('busy');
  });


  // ----------------------------------------
  // 3) Password strength bar + hints (English)
  //    CSP-safe for the bar: class-based only
  // ----------------------------------------
  var strengthLabels = ["Very weak", "Weak", "Fair", "Good", "Strong"];

  function setStrengthClass($fill, score) {
    score = Math.max(0, Math.min(4, score));
    $fill
      .removeClass('strength-s0 strength-s1 strength-s2 strength-s3 strength-s4')
      .addClass('strength-s' + score);
  }

  function buildHint(result) {
    if (result.score >= 4) return "";

    var pwd = result.password || "";
    if (pwd.length < 10) return "Make it longer.";

    if (result.sequence && result.sequence.some(function (m) {
      return m.pattern === 'dictionary' || m.pattern === 'repeat' || m.pattern === 'sequence';
    })) {
      return "Avoid common words and predictable patterns. Add more words (use a passphrase).";
    }

    return "Use a mix of upper/lowercase, numbers, and symbols. Add more words (use a passphrase).";
  }


  // ----------------------------------------
  // 4) Random password generator (dice icon)
  //    - Dice icon goes between control and strength bar
  // ----------------------------------------
  function randomInt(max) {
    // cryptographically strong RNG
    var a = new Uint32Array(1);
    window.crypto.getRandomValues(a);
    return a[0] % max;
  }

  function generatePassword(length) {
    // Exclude ambiguous characters
    var lower = "abcdefghijkmnopqrstuvwxyz";
    var upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    var digits = "23456789";
    var symbols = "!@#$%^&*()-_=+[]{};:,.?";

    var all = lower + upper + digits + symbols;

    // Ensure at least one of each category
    var required = [
      lower[randomInt(lower.length)],
      upper[randomInt(upper.length)],
      digits[randomInt(digits.length)],
      symbols[randomInt(symbols.length)]
    ];

    length = Math.max(length || 16, required.length);

    var chars = required.slice();
    while (chars.length < length) {
      chars.push(all[randomInt(all.length)]);
    }

    // Shuffle (Fisher-Yates)
    for (var i = chars.length - 1; i > 0; i--) {
      var j = randomInt(i + 1);
      var tmp = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }

    return chars.join("");
  }

  function setInputValueAndTrigger($input, value) {
    $input.val(value);
    // Trigger input so strength/hints update
    $input.trigger('input');
  }


  // ----------------------------------------------------
  // 5) Inject dice icon + strength bar + hint
  //    For each .wantstrength input
  // ----------------------------------------------------
  $('.wantstrength').each(function () {
    var $pw = $(this);

    // Anchor to the input's .input-container (created above)
    var $container = $pw.parent().hasClass('input-container') ? $pw.parent() : $pw;

    // Add dice icon after the control (between control and bar)
    // Avoid duplicates
    var $existingDice = $container.next('.sme-dice');
    if (!$existingDice.length) {
      var $dice = $(
        '<img src="images/dice_3293.png" alt="Generate password" title="Generate password" class="sme-dice" />'
      );
      $container.after($dice);
    }

    // Add strength bar after dice
    var $diceNow = $container.next('.sme-dice');
    var $existingBar = $diceNow.length ? $diceNow.next('.sme-strength') : $container.next('.sme-strength');

    if (!$existingBar.length) {
      var $bar = $('<span class="sme-strength" aria-hidden="true"></span>');
      var $fill = $('<span class="sme-strength__fill strength-s0"></span>');
      $bar.append($fill);

      if ($diceNow.length) $diceNow.after($bar);
      else $container.after($bar);

      $pw.data('strengthFill', $fill);
    } else {
      var $fillExisting = $existingBar.find('.sme-strength__fill').first();
      if ($fillExisting.length) $pw.data('strengthFill', $fillExisting);
    }

    // Hint under bar (preferred), otherwise under container
    var $barNow = ($diceNow.length ? $diceNow.next('.sme-strength') : $container.next('.sme-strength'));
    var $after = $barNow.length ? $barNow : ($diceNow.length ? $diceNow : $container);

    if (!$after.next().hasClass('sme-pwd-hint')) {
      $('<div class="sme-pwd-hint"></div>').insertAfter($after);
    }
  });

	// Dice click handler (delegated) - respects current visibility state
	$(document).on('click', '.sme-dice', function () {
	  var $container = $(this).prevAll('.input-container').first();
	  var $input = $container.find('.sme-password.wantstrength').first();
	  if (!$input.length) return;

	  // default 16; optionally override by adding data-pwdlen="20" to input
	  var lenAttr = parseInt($input.attr('data-pwdlen'), 10);
	  var length = isFinite(lenAttr) && lenAttr > 0 ? lenAttr : 16;

	  // Preserve current visibility state
	  var currentType = ($input.attr('type') === 'text') ? 'text' : 'password';

	  var pwd = generatePassword(length);

	  // Set value and keep current type (visible/non-visible)
	  $input.val(pwd);
	  $input.attr('type', currentType);

	  // Trigger input so strength/hints update
	  $input.trigger('input');

	  // Select for easy copy
	  $input.trigger('focus');
	  try { $input[0].setSelectionRange(0, pwd.length); } catch (e) { /* ignore */ }
	});


  // Strength update on input (delegated)
  $(document).on('input', '.wantstrength', function () {
    var $pw = $(this);
    var val = $pw.val() || "";

    var $container = $pw.parent().hasClass('input-container') ? $pw.parent() : $pw;
    var $dice = $container.next('.sme-dice');
    var $bar = $dice.length ? $dice.next('.sme-strength') : $container.next('.sme-strength');
    var $hint = $bar.length ? $bar.next('.sme-pwd-hint')
      : ($dice.length ? $dice.next('.sme-pwd-hint') : $container.next('.sme-pwd-hint'));

    var $fill = $pw.data('strengthFill');
    if ((!$fill || !$fill.length) && $bar.length) {
      $fill = $bar.find('.sme-strength__fill').first();
      if ($fill.length) $pw.data('strengthFill', $fill);
    }

    if (!$fill || !$fill.length) {
      console.log("Password strength: fill element not found for", this);
      return;
    }

    if (!val) {
      setStrengthClass($fill, 0);
      if ($hint.length) $hint.text('');
      return;
    }

    if (typeof window.zxcvbn !== "function") {
      console.log("Password strength: zxcvbn not loaded (window.zxcvbn missing)");
      setStrengthClass($fill, 0);
      if ($hint.length) $hint.text('');
      return;
    }

    var result = window.zxcvbn(val);
    setStrengthClass($fill, result.score);

    var label = strengthLabels[result.score] || "";
    var extra = buildHint(result);
    if ($hint.length) $hint.text(extra ? (label + " — " + extra) : label);
  });

});