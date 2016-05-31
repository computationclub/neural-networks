# Neural networks that learn

Command-line options are available to use different network procs, and to load/store networks from different files. This is useful to compare performance of, say, different numbers of medial neurons, or the presence/different values for the bias neuron.

For example:

    ruby net.rb -n polar -t 10000
    [10000] error: 0.226980190663207647
    Average error is now 0.3700989397577589

... will create a new neural network to solve the polar problem, train it for 10,000 iterations, and then save the resulting network in `polar.yml`. It also outputs the error as the training runs, and at the end, a summary of the change in error between the start of training and the end of training.

If you run this command again, it will load the network from that file, and train it for an additional 10,000 iterations.

    $ ruby net.rb -n polar -t 10000
    [10000] error: 0.409728818634105156
    Average error is BETTER (0.3700989397577589 => 0.26626328280808154)

We can see that the performance of the network has improved as a result of more training. This isn't always the case, but it's good to see!

### Testing different options

Sometimes it's useful to train a new network on the same problem with some different options. To ensure you don't accidentally re-use the original network data, you can either delete the `.yml` file, or provide a new one:

    $ ruby net.rb -n polar -f other-polar.yml -t 1000
    [1000] error: 0.14169975008489225
    Average error is now 0.45853132744181596

This will start training a new polar-solving neural network, to be saved in the file `other-polar.yml` instead of the default `polar.yml`.


## Running a neural network

To test the network, run it without the `-t` argument and with the coordinates instead:

    $ ruby net.rb -n polar 0.5 1.25
    [0.5, 1.25] => [0.15725977743158615, 0.5192558328883411]
          expected [0.15766118119763434, 0.4744923096777931]
        difference [0.0004014037660481917, -0.044763523210547995]

... will output the result of the network, along with the actual values and a summary of the errors

By default this will use the pre-stored data in `polar.yml`, but if you provide a different file via the `-f` option, it will use that file instead:

    $ ruby net.rb -n polar -f other-polar.yml 0.5 1.25
    [0.5, 1.25] => [0.08525546224338806, 0.3280546140683748]
          expected [0.15766118119763434, 0.4744923096777931]
        difference [0.07240571895424627, 0.14643769560941833]

(Incidentally, you can see here that our second network is significantly worse because it's only been trained for 1,000 iterations.)


## Solving different problems

When training, the `NeuralNetwork` object generates and checks expected values for inputs by using user-supplied `Proc` objects. You can see these defined at the bottom of the script. The general form is:

    input_proc: <some proc that returns an array of N numbers, probably Floats>
    target_proc: <another proc that takes such an array of numbers, and returns another array of expected output values>

The number of input neurons is determined by the number of values returned by the input proc. Similarly, the number of output neurons is determined by the number of elements in the target proc.

You can define essentially any pair of procs to supply to the network for experimentation; it's vital to remember that these procs should *always* return `Array` instances though, even (as is the case with addition) they only hold a single element.


## Example pre-trained networks

Included are some example networks that have been pre-trained using at least a million iterations. You can use these saved networks by providing the `-f` option on the command line:

    $ruby net.rb -n polar -f polar.sample.yml 0.5 1.25
    [0.5, 1.25] => [0.16353739837890297, 0.4646445268662749]
          expected [0.15766118119763434, 0.4744923096777931]
        difference [-0.005876217181268628, 0.009847782811518213]

    $ ruby net.rb -n addition -f addition.sample.yml 4 7
    [4.0, 7.0] => [11.01291274035201]
         expected [11.0]
       difference [-0.012912740352010843]
