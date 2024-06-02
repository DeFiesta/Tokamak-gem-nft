import { ethers } from 'ethers'; // Correct import for ethers
import dotenv from 'dotenv';
dotenv.config();
import Bluebird from 'bluebird';
import fs from 'fs';

const fsp = Bluebird.promisifyAll(fs);

function promisify(fn: Function) {
  return function promisified(...params: any[]) {
    return new Bluebird((resolve, reject) =>
      fn(...params.concat([(err: any, ...args: any[]) => err ? reject(err) : resolve(args.length < 2 ? args[0] : args)]))
    );
  };
}

const readdirAsync = promisify(fsp.readdir) as (path: string) => Bluebird<string[]>;

export const readContracts = async (folder: string) => {
  let abis: { [key: string]: any } = {};
  let names: string[] = [];

  await readdirAsync(folder).then((filenames: string[]) => {
    filenames.forEach((e: string) => {
      if (e.indexOf(".json") > 0) {
        const name = e.substring(0, e.indexOf(".json"));
        names.push(name);
        abis[name] = require(`${folder}/${e}`);
      }
    });
  });

  return { names, abis };
};

export const deployedContracts = async (names: string[], abis: { [key: string]: any }, provider: any) => {
  let deployed: { [key: string]: ethers.Contract } = {};

  names.forEach((name: string) => {
    deployed[name] = new ethers.Contract(abis[name].address, abis[name].abi, provider);
  });

  return deployed;
};
