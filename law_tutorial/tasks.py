# coding: utf-8

import law  # type: ignore
import luigi

from law_tutorial.framework import Task, HTCondorWorkflow, CrabWorkflow


class ConvertNumber(Task, law.LocalWorkflow, HTCondorWorkflow, CrabWorkflow):

    def create_branch_map(self):
        return {
            i: 97 + i
            for i in range(26)
        }

    def output(self):
        return self.remote_target(f"output_{self.branch}.txt")

    def run(self):
        number = self.branch_map[self.branch]
        # same as
        # number = self.branch_data

        # convert the number --> this is the payload of this task
        char = chr(number)

        with self.output().open("w") as f:
            f.write(f"{char}\n")

        print(f"converted {number} to {char}")


class UpperCase(Task, law.LocalWorkflow, HTCondorWorkflow, CrabWorkflow):

    def create_branch_map(self):
        return {
            i: 97 + i
            for i in range(26)
        }

    def requires(self):
        return ConvertNumber.req(self)

    def output(self):
        return self.remote_target(f"output_{self.branch}.txt")

    def run(self):
        char = self.input().load(formatter="text")
        self.output().dump(char.upper(), formatter="text")
